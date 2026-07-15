import AppKit

/// A small cloud-style pixel speech bubble. The silhouette is the union of a
/// core rectangle (holding the text) and a ring of overlapping discs along its
/// edges — producing a bumpy cloud outline. That mask is then outlined by
/// eroding it one pixel, so the 1px border follows every bump and the tail
/// seamlessly. Text uses the hand-authored `PixelFont`, scaled up
/// nearest-neighbor to stay crisp.
final class SpeechBubbleView: NSView {

    var text: String = "" {
        didSet { cachedImage = nil; needsDisplay = true }
    }

    /// Horizontal position of the tail, as a fraction of the bubble width, set
    /// so the tail points at the cat.
    var tailFraction: CGFloat = 0.5 {
        didSet { cachedImage = nil; needsDisplay = true }
    }

    var onClick: (() -> Void)?

    override var isFlipped: Bool { false }

    /// On-screen size of one art pixel. Small, so the bubble stays compact.
    static let pixelSize: CGFloat = 3

    // Layout in art pixels.
    private let corePadX = 2
    private let corePadY = 1
    private let bumpRadius = 3
    private let tailW = 3
    private let tailH = 2

    private let fillColor = NSColor.white.cgColor
    private let inkColor = NSColor(srgbRed: 0.18, green: 0.15, blue: 0.13, alpha: 1).cgColor

    private var cachedImage: CGImage?

    // MARK: - Geometry (art pixels)

    private var coreW: Int { PixelFont.widthInPixels(text) + 2 * corePadX }
    private var coreH: Int { PixelFont.glyphHeight + 2 * corePadY }
    private var coreLeft: Int { bumpRadius }
    private var coreBottom: Int { tailH + bumpRadius }
    private var coreRight: Int { coreLeft + coreW }
    private var coreTop: Int { coreBottom + coreH }

    private func pixelDimensions() -> (w: Int, h: Int) {
        (coreW + 2 * bumpRadius, coreH + 2 * bumpRadius + tailH)
    }

    func fittedSize() -> NSSize {
        let (w, h) = pixelDimensions()
        return NSSize(width: CGFloat(w) * Self.pixelSize, height: CGFloat(h) * Self.pixelSize)
    }

    // MARK: - Shape

    /// The cloud silhouette (core rect + edge discs + tail) as a boolean mask.
    private func buildMask(w: Int, h: Int, tailCenter: Int) -> [[Bool]] {
        let r = bumpRadius
        let step = 2 * r - 1                     // disc spacing (slight overlap → bumps)
        let midY = coreBottom + coreH / 2

        // Disc centers ringing the core: along the top and bottom edges, plus a
        // bump on each end and one over the tail so it joins the body.
        var centers: [(x: Int, y: Int)] = []
        var cx = coreLeft
        while cx < coreRight {
            centers.append((cx, coreTop - 1))
            centers.append((cx, coreBottom))
            cx += step
        }
        centers.append((coreRight - 1, coreTop - 1))
        centers.append((coreRight - 1, coreBottom))
        centers.append((coreLeft, midY))         // rounded left end
        centers.append((coreRight - 1, midY))     // rounded right end
        centers.append((tailCenter, coreBottom))  // bridge the tail into the body

        let r2 = r * r
        var mask = Array(repeating: Array(repeating: false, count: h), count: w)
        for x in 0..<w {
            for y in 0..<h {
                if x >= coreLeft && x < coreRight && y >= coreBottom && y < coreTop {
                    mask[x][y] = true            // solid core (holds the text)
                } else if y < tailH {
                    mask[x][y] = abs(x - tailCenter) <= y  // tail triangle (tip at y=0)
                } else {
                    for c in centers where (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r2 {
                        mask[x][y] = true
                        break
                    }
                }
            }
        }
        return mask
    }

    // MARK: - Rendering

    private func renderPixelImage() -> CGImage? {
        let (w, h) = pixelDimensions()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = gctx
        gctx.shouldAntialias = false
        let ctx = gctx.cgContext
        ctx.setShouldAntialias(false)
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))

        func px(_ x: Int, _ y: Int, _ color: CGColor) {
            ctx.setFillColor(color)
            ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }

        let tailCenter = min(max(tailW / 2, Int((CGFloat(w) * tailFraction).rounded())),
                             w - 1 - tailW / 2)
        let mask = buildMask(w: w, h: h, tailCenter: tailCenter)

        // Ink the whole silhouette, then carve the white interior by eroding the
        // mask one pixel, leaving a clean 1px outline that hugs every bump.
        for x in 0..<w {
            for y in 0..<h where mask[x][y] {
                px(x, y, inkColor)
            }
        }
        for x in 1..<(w - 1) {
            for y in 1..<(h - 1) where mask[x][y]
                && mask[x - 1][y] && mask[x + 1][y]
                && mask[x][y - 1] && mask[x][y + 1] {
                px(x, y, fillColor)
            }
        }

        // Text, centered in the core.
        let textW = PixelFont.widthInPixels(text)
        let startX = (w - textW) / 2
        let topY = coreBottom + corePadY + PixelFont.glyphHeight - 1
        var penX = startX
        for character in text {
            for (row, bits) in PixelFont.rows(for: character).enumerated() {
                for (col, bit) in bits.enumerated() where bit == "1" {
                    px(penX + col, topY - row, inkColor)
                }
            }
            penX += PixelFont.glyphWidth + PixelFont.spacing
        }

        return rep.cgImage
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if cachedImage == nil { cachedImage = renderPixelImage() }
        guard let image = cachedImage else { return }
        ctx.interpolationQuality = .none // nearest-neighbor: crisp pixels
        ctx.draw(image, in: bounds)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
