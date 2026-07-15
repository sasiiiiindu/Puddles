import AppKit

/// A blocky, pixel-style speech bubble drawn with solid fills (no anti-aliased
/// curves) and a little tail pointing down toward the cat.
final class SpeechBubbleView: NSView {

    var text: String = "" {
        didSet { needsDisplay = true }
    }

    var onClick: (() -> Void)?

    override var isFlipped: Bool { false }

    /// Height of the downward tail region at the bottom of the view.
    private let tailHeight: CGFloat = 8

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.interpolationQuality = .none

        let border: CGFloat = 2
        let body = CGRect(x: 0, y: tailHeight,
                          width: bounds.width,
                          height: bounds.height - tailHeight)

        // Pixel border = black rect with a slightly smaller white rect on top.
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(body)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(body.insetBy(dx: border, dy: border))

        // Blocky tail pointing down toward the cat (black outline + white fill).
        let tailX = bounds.width * 0.30
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: tailX, y: 0, width: 10, height: tailHeight + border))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: tailX + border, y: border, width: 10 - border * 2, height: tailHeight))

        // Message, centered in the bubble body.
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let string = NSAttributedString(string: text, attributes: attrs)
        let size = string.size()
        let origin = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: body.minY + (body.height - size.height) / 2
        )
        string.draw(at: origin)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
