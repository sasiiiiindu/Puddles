import AppKit

/// A layer-backed view that cycles through a sprite sheet's frames at a given
/// frame rate, rendered with nearest-neighbor interpolation so scaled-up
/// pixel art stays crisp. The current sheet and fps can be swapped at runtime
/// (e.g. walk vs. idle). Can be mirrored horizontally to face either way.
final class SpriteView: NSView {

    private var frames: [CGImage] = []
    private var frameIndex = 0
    private var fps: Double = 8
    private var animationTimer: Timer?

    /// When true, the sprite is mirrored horizontally. Base art faces left, so
    /// mirroring makes it face right.
    var facingRight = false {
        didSet { needsDisplay = true }
    }

    /// Called when the sprite is clicked.
    var onClick: (() -> Void)?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Non-flipped: draw with a bottom-left origin so CGImages render upright.
    override var isFlipped: Bool { false }

    /// Switch to a sheet and (re)start cycling its frames at `fps`.
    func play(sheet: SpriteSheet, fps: Double) {
        frames = sheet.frames
        self.fps = fps
        frameIndex = 0
        needsDisplay = true
        restartTimer()
    }

    /// Stops any animation and shows a single fixed frame from `sheet`
    /// (e.g. tucked legs while airborne during the arrival hop).
    func showStaticFrame(sheet: SpriteSheet, index: Int) {
        stopAnimating()
        frames = sheet.frames
        guard frames.indices.contains(index) else { needsDisplay = true; return }
        frameIndex = index
        needsDisplay = true
    }

    /// Plays a two-frame blink loop with independent hold times for the open
    /// (frame 0) and closed (frame 1) frames — e.g. eyes open ~2.5s, then a
    /// quick ~0.2s blink. A constant-fps loop can't express that asymmetry.
    func playBlink(sheet: SpriteSheet, openDuration: Double, closedDuration: Double) {
        stopAnimating()
        frames = sheet.frames
        frameIndex = 0
        needsDisplay = true
        guard frames.count >= 2 else { return }
        scheduleBlink(open: openDuration, closed: closedDuration)
    }

    private func scheduleBlink(open: Double, closed: Double) {
        // Hold the currently shown frame for its own duration, then flip.
        let interval = frameIndex == 0 ? open : closed
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, self.frames.count >= 2 else { return }
            self.frameIndex = self.frameIndex == 0 ? 1 : 0
            self.needsDisplay = true
            self.scheduleBlink(open: open, closed: closed)
        }
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func restartTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
        guard fps > 0, frames.count > 1 else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            guard let self, !self.frames.isEmpty else { return }
            self.frameIndex = (self.frameIndex + 1) % self.frames.count
            self.needsDisplay = true
        }
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

    /// With no click handler (e.g. the Preferences previews), stay transparent
    /// to clicks so views underneath (the SwiftUI selection button) get them.
    override func hitTest(_ point: NSPoint) -> NSView? {
        onClick == nil ? nil : super.hitTest(point)
    }
}
