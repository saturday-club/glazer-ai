// ScreenCaptureService.swift
// GlazerAI
//
// Wraps CGWindowListCreateImage to capture a screen region and return PNG data.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Errors

/// Errors produced by ``ScreenCaptureService``.
enum ScreenCaptureError: LocalizedError {
    /// Screen Recording permission has not been granted.
    case permissionDenied
    /// The provided rectangle had zero or negative area after normalisation.
    case invalidRect
    /// Core Graphics failed to produce an image.
    case captureFailure
    /// PNG conversion of the captured image failed.
    case pngConversionFailure

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
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
final class ScreenCaptureService {

    // MARK: - Public API

    /// Captures the region described by `rect` (in AppKit screen coordinates,
    /// where the origin is bottom-left of the main display) and returns PNG data.
    ///
    /// - Parameter rect: The region to capture in AppKit screen coordinates.
    /// - Returns: PNG-encoded `Data` of the captured region.
    /// - Throws: ``ScreenCaptureError`` on failure.
    func capture(rect: CGRect) throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }

        let normalised = normalise(rect: rect)

        guard normalised.width  >= Constants.minimumSelectionSize,
              normalised.height >= Constants.minimumSelectionSize else {
            throw ScreenCaptureError.invalidRect
        }

        let cgRect = convertToCGScreenCoordinates(appKitRect: normalised)

        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw ScreenCaptureError.captureFailure
        }

        let nsImage = NSImage(cgImage: cgImage, size: normalised.size)
        guard let pngData = nsImage.pngData() else {
            throw ScreenCaptureError.pngConversionFailure
        }

        return pngData
    }

    // MARK: - Coordinate Conversion (internal for testing)

    /// Normalises a rectangle so that width and height are always positive.
    ///
    /// A drag from bottom-right to top-left produces negative dimensions;
    /// this function corrects the origin so the rect is well-formed.
    ///
    /// - Parameter rect: Any `CGRect`, possibly with negative dimensions.
    /// - Returns: An equivalent `CGRect` with non-negative width and height.
    func normalise(rect: CGRect) -> CGRect {
        // Use rect.size.width/height — CGRect.width/height return absolute values
        // and cannot be used to detect a negative dimension.
        CGRect(
            x: rect.size.width  < 0 ? rect.origin.x + rect.size.width  : rect.origin.x,
            y: rect.size.height < 0 ? rect.origin.y + rect.size.height : rect.origin.y,
            width: abs(rect.size.width),
            height: abs(rect.size.height)
        )
    }

    /// Converts an AppKit screen-coordinate rect (origin at bottom-left of main
    /// display) to a Core Graphics rect (origin at top-left of main display).
    ///
    /// - Parameter appKitRect: Rectangle in AppKit/NSScreen coordinates.
    /// - Returns: Rectangle in CG screen coordinates.
    func convertToCGScreenCoordinates(appKitRect: CGRect) -> CGRect {
        guard let screenHeight = NSScreen.main?.frame.height else {
            return appKitRect
        }
        return CGRect(
            x: appKitRect.origin.x,
            y: screenHeight - appKitRect.origin.y - appKitRect.height,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}

// MARK: - NSImage PNG Helper

private extension NSImage {
    /// Returns PNG-encoded data for this image, or `nil` on failure.
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
