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
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported — use init(frame:)")
    }

    // MARK: - Public API

    /// Resets all drag state. Call before presenting the overlay for a fresh snip.
    func reset() {
        anchorPoint = .zero
        currentRect = .zero
        isDragging = false
        needsDisplay = true
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Cursor

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Full-screen dim layer.
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: Constants.overlayDimOpacity)
        context.fill(bounds)

        // Instruction card (shown until first mouse-down).
        if !isDragging && currentRect == .zero {
            drawInstructionCard(in: context)
        }

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

    /// Handles Escape via the standard AppKit cancel-operation mechanism.
    override func cancelOperation(_ sender: Any?) {
        delegate?.snippingViewDidCancel(self)
    }

    /// Fallback: also handle raw keyDown for systems where cancelOperation is not routed.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            delegate?.snippingViewDidCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Private Helpers

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    /// Returns the current selection rectangle with positive width and height.
    private func normalisedSelection() -> CGRect {
        CGRect(
            x: currentRect.size.width  < 0 ? currentRect.origin.x + currentRect.size.width  : currentRect.origin.x,
            y: currentRect.size.height < 0 ? currentRect.origin.y + currentRect.size.height : currentRect.origin.y,
            width: abs(currentRect.size.width),
            height: abs(currentRect.size.height)
        )
    }

    // MARK: - Instruction Card

    private typealias TextEntry = (text: NSString, attrs: [NSAttributedString.Key: Any])

    /// Draws a centered instruction card explaining what to do.
    private func drawInstructionCard(in context: CGContext) {
        let entries: [TextEntry] = [
            ("GlazerAI", [.font: NSFont.systemFont(ofSize: 22, weight: .semibold),
                          .foregroundColor: NSColor.white]),
            ("Drag to select a LinkedIn profile", [.font: NSFont.systemFont(ofSize: 15, weight: .regular),
                                                   .foregroundColor: NSColor(white: 0.85, alpha: 1)]),
            ("Press Esc to cancel", [.font: NSFont.systemFont(ofSize: 12, weight: .regular),
                                     .foregroundColor: NSColor(white: 0.55, alpha: 1)])
        ]
        let sizes = entries.map { $0.text.size(withAttributes: $0.attrs) }

        let lineSpacing: CGFloat = 10
        let cardPadding: CGFloat = 28
        let cardWidth  = sizes.map(\.width).max()! + cardPadding * 2
        let cardHeight = sizes.map(\.height).reduce(0, +)
                       + lineSpacing * CGFloat(sizes.count - 1) + cardPadding * 2

        let cardRect = CGRect(
            x: (bounds.width  - cardWidth)  / 2,
            y: (bounds.height - cardHeight) / 2,
            width: cardWidth,
            height: cardHeight
        )

        let layout = CardLayout(rect: cardRect, lineSpacing: lineSpacing, padding: cardPadding)
        drawCardBackground(rect: cardRect, in: context)
        drawCardText(entries: entries, sizes: sizes, layout: layout, in: context)
    }

    private func drawCardBackground(rect: CGRect, in context: CGContext) {
        let path = CGMutablePath()
        path.addRoundedRect(in: rect, cornerWidth: 14, cornerHeight: 14)
        context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.92))
        context.addPath(path)
        context.fillPath()
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()
    }

    private struct CardLayout {
        let rect: CGRect
        let lineSpacing: CGFloat
        let padding: CGFloat
    }

    private func drawCardText(entries: [TextEntry], sizes: [CGSize], layout: CardLayout, in context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        var yPos = layout.rect.maxY - layout.padding
        for (entry, size) in zip(entries, sizes) {
            yPos -= size.height
            let origin = CGPoint(x: layout.rect.minX + (layout.rect.width - size.width) / 2, y: yPos)
            entry.text.draw(at: origin, withAttributes: entry.attrs)
            yPos -= layout.lineSpacing
        }

        NSGraphicsContext.restoreGraphicsState()
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
