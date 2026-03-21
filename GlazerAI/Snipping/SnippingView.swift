// SnippingView.swift
// GlazerAI
//
// Full-screen NSView that renders the dim overlay, the clear selection
// rectangle, the blue border, and the W×H dimension label.

import AppKit
import Foundation

// MARK: - Delegate

/// Receives snipping events from ``SnippingView``.
@MainActor
protocol SnippingViewDelegate: AnyObject {
    /// Called when the user releases the mouse to confirm a selection.
    func snippingView(_ view: SnippingView, didConfirmRect rect: CGRect)
    /// Called when the user presses Escape to cancel.
    func snippingViewDidCancel(_ view: SnippingView)
}

// MARK: - View

/// Transparent full-screen view that handles mouse drag selection and drawing.
final class SnippingView: NSView {

    // MARK: - Properties

    /// Notified when the user confirms or cancels a selection.
    weak var delegate: SnippingViewDelegate?

    private var anchorPoint: CGPoint = .zero
    private var currentRect: CGRect = .zero
    private var isDragging = false

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init(frame:)")
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Full-screen dim layer.
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: Constants.overlayDimOpacity)
        context.fill(bounds)

        guard isDragging else { return }

        let selection = normalisedSelection()
        guard selection.width  >= Constants.minimumSelectionSize,
              selection.height >= Constants.minimumSelectionSize else { return }

        // Clear the selected region (remove dim).
        context.clear(selection)

        // Blue 1pt border.
        context.setStrokeColor(
            red: Constants.selectionBorderRed,
            green: Constants.selectionBorderGreen,
            blue: Constants.selectionBorderBlue,
            alpha: 1.0
        )
        context.setLineWidth(Constants.selectionBorderWidth)
        context.stroke(selection)

        // Dimension label.
        drawDimensionLabel(for: selection, in: context)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        anchorPoint = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(origin: anchorPoint, size: .zero)
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: anchorPoint.x,
            y: anchorPoint.y,
            width: current.x - anchorPoint.x,
            height: current.y - anchorPoint.y
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        let finalRect = normalisedSelection()
        guard finalRect.width  >= Constants.minimumSelectionSize,
              finalRect.height >= Constants.minimumSelectionSize else {
            delegate?.snippingViewDidCancel(self)
            return
        }
        delegate?.snippingView(self, didConfirmRect: finalRect)
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        // Escape key (keyCode 53) cancels.
        if event.keyCode == 53 {
            delegate?.snippingViewDidCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Private Helpers

    /// Returns the current selection rectangle with positive width and height.
    private func normalisedSelection() -> CGRect {
        // Use size.width/height — CGRect.width/height return absolute values.
        CGRect(
            x: currentRect.size.width  < 0 ? currentRect.origin.x + currentRect.size.width  : currentRect.origin.x,
            y: currentRect.size.height < 0 ? currentRect.origin.y + currentRect.size.height : currentRect.origin.y,
            width: abs(currentRect.size.width),
            height: abs(currentRect.size.height)
        )
    }

    /// Draws an integer W×H label near the bottom-right of `rect`.
    private func drawDimensionLabel(for rect: CGRect, in context: CGContext) {
        let label = "\(Int(rect.width)) × \(Int(rect.height))" as NSString

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let labelSize = label.size(withAttributes: attributes)
        let padding: CGFloat = 4.0
        let labelOrigin = CGPoint(
            x: rect.maxX - labelSize.width  - padding,
            y: rect.minY - labelSize.height - padding
        )

        label.draw(at: labelOrigin, withAttributes: attributes)
    }
}
