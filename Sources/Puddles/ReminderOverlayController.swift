import AppKit

/// Owns one reminder overlay: a borderless, transparent, always-on-top,
/// non-activating panel in which a pixel-art cat walks in from a screen edge,
/// shows a speech bubble, waits, then walks back off-screen.
///
/// Choreography:
///   1. Cat starts off-screen at a randomly chosen (left/right) edge and walks
///      in over ~1.5s, playing `walk.png` and facing its direction of travel.
///   2. On arrival it does two quick springy hops in place, then switches to
///      `idle.png` (slow blink) and a speech bubble with a random hydration
///      message pops in above it.
///   3. After 8 seconds it turns around, plays `walk.png` (flipped), and walks
///      off the same edge (~1.5s).
///   4. The panel closes.
/// Clicking the cat (or bubble) dismisses everything immediately.
final class ReminderOverlayController: NSObject {

    private enum Side { case left, right }

    /// Short, friendly hydration messages; one is chosen at random per reminder.
    private static let messages = [
        "DRINK UP",
        "HYDRATE",
        "WATER BREAK",
        "SIP SIP",
        "THIRSTY?",
        "STAY FRESH",
        "TIME TO SIP",
        "SPLASH",
    ]

    private var panel: NSPanel?
    private var spriteView: SpriteView?
    private var bubble: SpeechBubbleView?
    private var idleWork: DispatchWorkItem?
    private var slideTimer: Timer?
    private var isDismissed = false

    // Chosen when the overlay is shown.
    private var side: Side = .right
    private var restX: CGFloat = 0
    private var offScreenX: CGFloat = 0

    // The character walking on screen; its sheets and frame timings drive
    // all animation (real art from Resources/, placeholder as fallback).
    private let character: Character
    private let walkSheet: SpriteSheet
    private let idleSheet: SpriteSheet

    /// Called once when the overlay has fully finished (walked off or dismissed).
    var onFinished: (() -> Void)?

    /// Called when the cat itself is clicked (counts as a glass of water).
    var onCatClicked: (() -> Void)?

    /// Testing hook: force the entry edge. `nil` (the default) picks randomly.
    var forcedSideLeft: Bool?

    // Rendering / layout constants.
    private let scale: CGFloat = 5
    private let framePixels = 16
    private var catSize: CGFloat { CGFloat(framePixels) * scale } // 80pt

    private let windowWidth: CGFloat = 320
    private let windowHeight: CGFloat = 200
    private let catBottomInset: CGFloat = 20
    private let restInset: CGFloat = 90 // gap from the entry edge when resting

    private let walkDuration: TimeInterval = 1.5

    // Arrival hop: two quick springy hops in place before the bubble appears.
    private let hopHeight: CGFloat = 8         // points off the ground at the peak
    private let hopRise: TimeInterval = 0.20   // ease-out up
    private let hopFall: TimeInterval = 0.15   // ease-in down, slightly faster → springy
    private let hopPause: TimeInterval = 0.10  // grounded beat between the two hops

    // Idle blink: eyes open long, blink brief.
    private let idleOpenDuration: TimeInterval = 2.5
    private let idleClosedDuration: TimeInterval = 0.2

    private var walkFPS: Double { character.walkFPS }
    private var idleFPS: Double { character.idleFPS }

    init(character: Character) {
        self.character = character
        walkSheet = character.walkSheet()
        idleSheet = character.idleSheet()
        super.init()
    }

    // MARK: - Show

    func show() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame

        side = (forcedSideLeft ?? Bool.random()) ? .left : .right

        // Horizontal geometry depends on which edge the cat enters from.
        let originX: CGFloat
        switch side {
        case .right:
            originX = vf.maxX - windowWidth
            offScreenX = windowWidth            // fully off the right edge
            restX = windowWidth - catSize - restInset
        case .left:
            originX = vf.minX
            offScreenX = -catSize               // fully off the left edge
            restX = restInset
        }

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

        // Cat sprite, starting fully off-screen at the chosen edge, walking in.
        let sprite = SpriteView()
        sprite.frame = NSRect(x: offScreenX, y: catBottomInset, width: catSize, height: catSize)
        sprite.facingRight = entryFacingRight
        sprite.onClick = { [weak self] in
            self?.onCatClicked?()
            self?.dismissImmediately()
        }
        sprite.play(sheet: walkSheet, fps: walkFPS)
        content.addSubview(sprite)

        // Speech bubble above the cat's resting spot, hidden until it arrives.
        // It sizes itself to its text (on a pixel grid).
        let bubble = SpeechBubbleView(frame: .zero)
        bubble.text = Self.messages.randomElement() ?? "DRINK UP"
        bubble.wantsLayer = true
        bubble.alphaValue = 0
        bubble.onClick = { [weak self] in self?.dismissImmediately() }

        // Center the bubble over the cat, clamp to the window, and aim the tail.
        let bubbleSize = bubble.fittedSize()
        let catCenterX = restX + catSize / 2
        let bubbleX = min(max(0, catCenterX - bubbleSize.width / 2),
                          windowWidth - bubbleSize.width)
        bubble.frame = NSRect(
            x: bubbleX,
            y: catBottomInset + catSize - 6,
            width: bubbleSize.width,
            height: bubbleSize.height
        )
        bubble.tailFraction = (catCenterX - bubbleX) / bubbleSize.width
        content.addSubview(bubble)

        self.panel = panel
        self.spriteView = sprite
        self.bubble = bubble

        panel.orderFrontRegardless()

        // Walk in, then greet.
        slide(sprite, toX: restX, duration: walkDuration) { [weak self] in
            self?.didArrive()
        }
    }

    // MARK: - Manual slide animation

    /// Moves `view` horizontally to `targetX` over `duration` at a steady pace,
    /// driven by a timer. Deterministic — unlike the `animator()` proxy, which
    /// was intermittently snapping the sprite off-screen instead of sliding.
    private func slide(_ view: NSView, toX targetX: CGFloat,
                       duration: TimeInterval, completion: @escaping () -> Void) {
        slideTimer?.invalidate()
        let startX = view.frame.origin.x
        let y = view.frame.origin.y
        let start = Date()
        slideTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak view] timer in
            guard let self, let view else { timer.invalidate(); return }
            let progress = min(1, Date().timeIntervalSince(start) / duration)
            let x = startX + (targetX - startX) * CGFloat(progress)
            view.setFrameOrigin(NSPoint(x: x, y: y))
            if progress >= 1 {
                timer.invalidate()
                if self.slideTimer === timer { self.slideTimer = nil }
                completion()
            }
        }
    }

    /// Animates `view`'s vertical position from `fromY` to `toY` over `duration`
    /// with a custom easing curve, driven by the same 60fps timer as `slide`
    /// (so dismissal/click cleanly cancels it). X is held constant.
    private func animateY(_ view: NSView, fromY: CGFloat, toY: CGFloat,
                          duration: TimeInterval, ease: @escaping (Double) -> Double,
                          completion: @escaping () -> Void) {
        slideTimer?.invalidate()
        let start = Date()
        slideTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak view] timer in
            guard let self, let view else { timer.invalidate(); return }
            let progress = min(1, Date().timeIntervalSince(start) / duration)
            let y = fromY + (toY - fromY) * CGFloat(ease(progress))
            view.setFrameOrigin(NSPoint(x: view.frame.origin.x, y: y))
            if progress >= 1 {
                timer.invalidate()
                if self.slideTimer === timer { self.slideTimer = nil }
                completion()
            }
        }
    }

    // Quadratic easing: ease-out decelerates into the peak, ease-in
    // accelerates into the landing.
    private static func easeOut(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
    private static func easeIn(_ t: Double) -> Double { t * t }

    // MARK: - Arrival hop

    /// Two quick springy hops in place, then `completion`.
    private func arrivalHops(then completion: @escaping () -> Void) {
        hop { [weak self] in
            guard let self, !self.isDismissed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.hopPause) { [weak self] in
                guard let self, !self.isDismissed else { return }
                self.hop { [weak self] in
                    guard let self, !self.isDismissed else { return }
                    completion()
                }
            }
        }
    }

    /// One hop: tuck the legs (walk frame 2) and rise with ease-out, then fall
    /// slightly faster with ease-in and plant the legs (walk frame 1). Facing is
    /// untouched, so a left-entry (mirrored) character hops correctly too.
    private func hop(completion: @escaping () -> Void) {
        guard let sprite = spriteView else { completion(); return }
        let groundY = catBottomInset
        let peakY = groundY + hopHeight

        sprite.showStaticFrame(sheet: walkSheet, index: 1) // airborne: tucked legs
        animateY(sprite, fromY: groundY, toY: peakY, duration: hopRise, ease: Self.easeOut) { [weak self] in
            guard let self, !self.isDismissed, let sprite = self.spriteView else { return }
            self.animateY(sprite, fromY: peakY, toY: groundY, duration: self.hopFall, ease: Self.easeIn) { [weak self] in
                guard let self, !self.isDismissed, let sprite = self.spriteView else { return }
                sprite.showStaticFrame(sheet: self.walkSheet, index: 0) // grounded
                completion()
            }
        }
    }

    // MARK: - Facing

    /// While walking in, the cat faces its direction of travel: entering from
    /// the left means moving right (mirrored), from the right means moving left.
    private var entryFacingRight: Bool { side == .left }

    // MARK: - Choreography

    private func didArrive() {
        guard !isDismissed, spriteView != nil else { return }

        // Two quick springy hops in place, then greet.
        arrivalHops { [weak self] in self?.greet() }
    }

    private func greet() {
        guard !isDismissed, let bubble, let sprite = spriteView else { return }

        // Stand still and blink: eyes open ~2.5s, quick ~0.2s blink.
        sprite.playBlink(sheet: idleSheet,
                         openDuration: idleOpenDuration,
                         closedDuration: idleClosedDuration)

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

        // Turn around and walk back off the same edge (walk.png, flipped).
        sprite.facingRight = !entryFacingRight
        sprite.play(sheet: walkSheet, fps: walkFPS)
        slide(sprite, toX: offScreenX, duration: walkDuration) { [weak self] in
            self?.close()
        }
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
        slideTimer?.invalidate()
        slideTimer = nil
        spriteView?.stopAnimating()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil

        onFinished?()
    }
}
