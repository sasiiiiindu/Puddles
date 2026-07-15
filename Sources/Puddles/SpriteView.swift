import AppKit

/// A layer-backed view that cycles through a sprite sheet's frames at a fixed
/// frame rate, rendered with nearest-neighbor interpolation so scaled-up
/// pixel art stays crisp. Can be flipped horizontally to face either way.
final class SpriteView: NSView {

    private let frames: [CGImage]
    private var frameIndex = 0
    private var animationTimer: Timer?

    /// When true, the sprite is mirrored horizontally (base art faces left).
    var facingRight = false {
        didSet { needsDisplay = true }
    }

    /// Called when the sprite is clicked.
    var onClick: (() -> Void)?

    init(sheet: SpriteSheet) {
        self.frames = sheet.frames
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Non-flipped: draw with a bottom-left origin so CGImages render upright.
    override var isFlipped: Bool { false }

    func startAnimating(fps: Double = 8) {
        stopAnimating()
        guard fps > 0 else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            guard let self, !self.frames.isEmpty else { return }
            self.frameIndex = (self.frameIndex + 1) % self.frames.count
            self.needsDisplay = true
        }
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              frames.indices.contains(frameIndex) else { return }

        ctx.interpolationQuality = .none // nearest-neighbor: keep pixels crisp
        ctx.saveGState()
        if facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        ctx.draw(frames[frameIndex], in: bounds)
        ctx.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
