// ScreenCaptureService.swift
// GlazerAI
//
// Captures a screen region using ScreenCaptureKit (macOS 14+).
// Excludes the Glazer AI overlay from the captured content.

import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

// MARK: - Errors

/// Errors produced by ``ScreenCaptureService``.
enum ScreenCaptureError: LocalizedError {
    /// Screen Recording permission has not been granted.
    case permissionDenied
    /// The provided rectangle had zero or negative area after normalisation.
    case invalidRect
    /// Could not find a matching display or SCShareableContent failed.
    case captureFailure
    /// PNG conversion of the captured image failed.
    case pngConversionFailure

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            // swiftlint:disable:next line_length
            return "Screen Recording permission is required. Go to System Settings → Privacy & Security → Screen Recording and enable Glazer AI, then try again."
        case .invalidRect:
            return "The selected region is too small to capture."
        case .captureFailure:
            return "Screen capture failed."
        case .pngConversionFailure:
            return "Failed to encode the captured image as PNG."
        }
    }
}

// MARK: - Service

/// Captures a user-defined rectangular region of the screen and returns PNG data.
///
/// Uses `SCScreenshotManager` (ScreenCaptureKit) for proper permission integration
/// and to exclude the Glazer AI overlay window from the captured content.
final class ScreenCaptureService: Sendable {

    // MARK: - Public API

    /// Captures `rect` (AppKit screen coordinates, origin bottom-left of main display)
    /// and returns PNG-encoded data.
    func capture(rect: CGRect) async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }

        let normalised = normalise(rect: rect)
        guard normalised.width  >= Constants.minimumSelectionSize,
              normalised.height >= Constants.minimumSelectionSize else {
            throw ScreenCaptureError.invalidRect
        }

        let content = try await SCShareableContent.current

        let nsScreen = screen(containing: normalised)
        let scDisplay = scDisplay(matching: nsScreen, from: content)

        // Exclude this app's overlay so it doesn't appear in the screenshot.
        let ownApp = content.applications.first(where: {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        })
        let filter = SCContentFilter(
            display: scDisplay,
            excludingApplications: ownApp.map { [$0] } ?? [],
            exceptingWindows: []
        )

        let displayRect = rectInDisplayCoordinates(normalised, screen: nsScreen)
        let scaleFactor = max(1, Int(filter.pointPixelScale))

        let config = SCStreamConfiguration()
        config.sourceRect = displayRect
        config.width = max(1, Int(displayRect.width) * scaleFactor)
        config.height = max(1, Int(displayRect.height) * scaleFactor)
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        let nsImage = NSImage(cgImage: cgImage, size: normalised.size)
        guard let pngData = nsImage.pngData() else {
            throw ScreenCaptureError.pngConversionFailure
        }
        return pngData
    }

    // MARK: - Internal helpers (tested)

    /// Returns the rect with positive width and height.
    func normalise(rect: CGRect) -> CGRect {
        CGRect(
            x: rect.size.width  < 0 ? rect.origin.x + rect.size.width  : rect.origin.x,
            y: rect.size.height < 0 ? rect.origin.y + rect.size.height : rect.origin.y,
            width: abs(rect.size.width),
            height: abs(rect.size.height)
        )
    }

    // MARK: - Private

    /// Returns the NSScreen that contains the rect's midpoint (falls back to main).
    private func screen(containing rect: CGRect) -> NSScreen {
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(mid) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// Finds the SCDisplay whose displayID matches `screen`. Falls back to first display.
    private func scDisplay(matching screen: NSScreen, from content: SCShareableContent) -> SCDisplay {
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return content.displays.first(where: { $0.displayID == id?.uint32Value }) ?? content.displays[0]
    }

    /// Converts a rect from AppKit screen coordinates (origin bottom-left) to
    /// display-local ScreenCaptureKit coordinates (origin top-left of that display).
    private func rectInDisplayCoordinates(_ rect: CGRect, screen: NSScreen) -> CGRect {
        let screenH = screen.frame.height + screen.frame.minY
        return CGRect(
            x: rect.origin.x - screen.frame.minX,
            y: screenH - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

// MARK: - NSImage PNG Helper

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff   = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
