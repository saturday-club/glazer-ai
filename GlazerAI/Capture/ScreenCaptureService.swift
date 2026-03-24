// ScreenCaptureService.swift
// GlazerAI
//
// Captures a screen region using the system `screencapture` CLI tool.
// Approach (from AutoLog/contextd):
// 1. Full-screen capture with `screencapture -x -t png <path>`
// 2. Crop to user's rect using CGImage.cropping(to:)
// Never call CG permission APIs or ScreenCaptureKit.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Errors

enum ScreenCaptureError: LocalizedError {
    case invalidRect
    case captureFailure
    case cropFailure
    case pngConversionFailure

    var errorDescription: String? {
        switch self {
        case .invalidRect:
            return "The selected region is too small to capture."
        case .captureFailure:
            return "Screen capture failed. Check Screen Recording permission in System Settings."
        case .cropFailure:
            return "Failed to crop the captured image to the selected region."
        case .pngConversionFailure:
            return "Failed to encode the captured image as PNG."
        }
    }
}

// MARK: - Service

final class ScreenCaptureService: Sendable {

    func capture(rect: CGRect) async throws -> Data {
        let normalised = normalise(rect: rect)
        guard normalised.width  >= Constants.minimumSelectionSize,
              normalised.height >= Constants.minimumSelectionSize else {
            throw ScreenCaptureError.invalidRect
        }

        // Step 1: Full-screen capture using screencapture CLI.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("glazerai-\(UUID().uuidString).png")
        let tempPath = tempURL.path

        let fullImage: CGImage = try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", "-t", "png", tempPath]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                print("[GlazerAI] screencapture exit code: \(process.terminationStatus)")
                throw ScreenCaptureError.captureFailure
            }

            let fileURL = URL(fileURLWithPath: tempPath)
            guard FileManager.default.fileExists(atPath: tempPath),
                  let provider = CGDataProvider(url: fileURL as CFURL),
                  let cgImage = CGImage(
                    pngDataProviderSource: provider,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent
                  ) else {
                print("[GlazerAI] Failed to load PNG from \(tempPath)")
                throw ScreenCaptureError.captureFailure
            }

            try? FileManager.default.removeItem(at: fileURL)
            return cgImage
        }.value

        // Step 2: Convert AppKit rect to image pixel coords and crop.
        let cropRect = rectInImageCoordinates(normalised, imageWidth: fullImage.width, imageHeight: fullImage.height)

        // Clamp to image bounds to prevent nil from cropping(to:).
        let imageBounds = CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height)
        let clampedRect = cropRect.intersection(imageBounds)

        guard !clampedRect.isEmpty,
              clampedRect.width >= 1,
              clampedRect.height >= 1,
              let cropped = fullImage.cropping(to: clampedRect) else {
            print("[GlazerAI] Crop failed. imageSize=\(fullImage.width)x\(fullImage.height) cropRect=\(cropRect) clamped=\(clampedRect)")
            throw ScreenCaptureError.cropFailure
        }

        // Step 3: Encode cropped CGImage directly to PNG (no NSImage round-trip).
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData as CFMutableData, "public.png" as CFString, 1, nil) else {
            throw ScreenCaptureError.pngConversionFailure
        }
        CGImageDestinationAddImage(dest, cropped, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ScreenCaptureError.pngConversionFailure
        }

        return mutableData as Data
    }

    // MARK: - Internal

    func normalise(rect: CGRect) -> CGRect {
        CGRect(
            x: rect.size.width  < 0 ? rect.origin.x + rect.size.width  : rect.origin.x,
            y: rect.size.height < 0 ? rect.origin.y + rect.size.height : rect.origin.y,
            width: abs(rect.size.width),
            height: abs(rect.size.height)
        )
    }

    // MARK: - Private

    /// Converts AppKit screen coordinates (origin bottom-left) to image pixel
    /// coordinates (origin top-left), accounting for Retina scaling.
    private func rectInImageCoordinates(
        _ rect: CGRect,
        imageWidth: Int,
        imageHeight: Int
    ) -> CGRect {
        guard let mainScreen = NSScreen.main else { return rect }

        let screenFrame = mainScreen.frame
        let scaleX = CGFloat(imageWidth) / screenFrame.width
        let scaleY = CGFloat(imageHeight) / screenFrame.height

        // AppKit origin = bottom-left, image origin = top-left.
        let cgY = screenFrame.height - rect.origin.y - rect.height

        return CGRect(
            x: floor(rect.origin.x * scaleX),
            y: floor(cgY * scaleY),
            width: ceil(rect.width * scaleX),
            height: ceil(rect.height * scaleY)
        )
    }
}
