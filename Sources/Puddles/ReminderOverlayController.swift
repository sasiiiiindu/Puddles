import AppKit

/// Owns one reminder overlay: a borderless, transparent, always-on-top,
/// non-activating panel in which a pixel-art cat walks in from the right edge,
/// shows a speech bubble, waits, then walks back off-screen.
///
/// Choreography:
///   1. Cat starts off-screen at the right edge, walks in over ~1.5s.
///   2. Speech bubble pops in above the cat.
///   3. After 8 seconds the cat turns around and walks off (~1.5s).
///   4. The panel closes.
/// Clicking the cat (or bubble) dismisses everything immediately.
final class ReminderOverlayController: NSObject {

    private let message: String

    private var panel: NSPanel?
    private var spriteView: SpriteView?
    private var bubble: SpeechBubbleView?
    private var idleWork: DispatchWorkItem?
    private var isDismissed = false

    /// Called once when the overlay has fully finished (walked off or dismissed).
    var onFinished: (() -> Void)?

    // Rendering constants.
    private let scale: CGFloat = 5
    private let frameCount = 4
    private let framePixels = 16
    private var catSize: CGFloat { CGFloat(framePixels) * scale } // 80pt

    private let windowWidth: CGFloat = 300
    private let windowHeight: CGFloat = 200
    private let catBottomInset: CGFloat = 20
    private let restInset: CGFloat = 40 // gap from the right edge when resting

    init(message: String) {
        self.message = message
        super.init()
    }

    // MARK: - Show

    func show() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame

        // Flush against the right edge of the usable screen area.
        let originX = vf.maxX - windowWidth

        // Random vertical position, avoiding the very top and bottom (~15% each).
        let vMargin = vf.height * 0.15
        let minY = vf.minY + vMargin
        let maxY = max(minY, vf.maxY - vMargin - windowHeight)
        let originY = CGFloat.random(in: minY...maxY)

        let panel = NSPanel(
            contentRect: NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar          // always on top
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false  // the cat needs to be clickable
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let content = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        content.wantsLayer = true
        panel.contentView = content

        // Cat sprite, starting fully off-screen at the right edge.
        let sheet = SpriteSheet.placeholder(frameCount: frameCount, frameSize: framePixels)
        let sprite = SpriteView(sheet: sheet)
        sprite.frame = NSRect(x: windowWidth, y: catBottomInset, width: catSize, height: catSize)
        sprite.facingRight = false // facing left while walking in
        sprite.onClick = { [weak self] in self?.dismissImmediately() }
        content.addSubview(sprite)

        // Speech bubble, positioned above the cat's resting spot, hidden at first.
        let bubbleWidth: CGFloat = 160
        let bubbleHeight: CGFloat = 56
        let restX = windowWidth - catSize - restInset
        let bubble = SpeechBubbleView(frame: .zero)
        bubble.text = message
        bubble.wantsLayer = true
        bubble.alphaValue = 0
        bubble.onClick = { [weak self] in self?.dismissImmediately() }

        var bubbleX = restX + catSize / 2 - bubbleWidth * 0.30 // align tail over cat
        bubbleX = min(max(0, bubbleX), windowWidth - bubbleWidth)
        bubble.frame = NSRect(
            x: bubbleX,
            y: catBottomInset + catSize - 6,
            width: bubbleWidth,
            height: bubbleHeight
        )
        content.addSubview(bubble)

        self.panel = panel
        self.spriteView = sprite
        self.bubble = bubble

        panel.orderFrontRegardless()
        sprite.startAnimating(fps: 8)

        // Walk in.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 1.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            sprite.animator().setFrameOrigin(NSPoint(x: restX, y: self.catBottomInset))
        }, completionHandler: { [weak self] in
            self?.didArrive()
        })
    }

    // MARK: - Choreography

    private func didArrive() {
        guard !isDismissed, let bubble else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            bubble.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { [weak self] in self?.walkOut() }
        idleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func walkOut() {
        guard !isDismissed, let sprite = spriteView, let bubble else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            bubble.animator().alphaValue = 0
        }

        sprite.facingRight = true // turn around
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 1.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            sprite.animator().setFrameOrigin(NSPoint(x: self.windowWidth, y: sprite.frame.origin.y))
        }, completionHandler: { [weak self] in
            self?.close()
        })
    }

    // MARK: - Dismissal

    func dismissImmediately() {
        close()
    }

    private func close() {
        guard !isDismissed else { return }
        isDismissed = true

        idleWork?.cancel()
        idleWork = nil
        spriteView?.stopAnimating()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil

        onFinished?()
    }
}
