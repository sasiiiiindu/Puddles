import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var reminderTimer: Timer?
    private var overlay: ReminderOverlayController?
    private var countItem: NSMenuItem!
    private var prefsWindow: NSWindow?

    private let prefs = Preferences.shared
    private let tracker = HydrationTracker.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startReminderTimer()
        NSLog("Puddles launched. Reminder interval: \(prefs.reminderIntervalMinutes) min.")

        // Reschedule the timer whenever the interval preference changes.
        prefs.$reminderIntervalMinutes
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.startReminderTimer() }
            }
            .store(in: &cancellables)

        // Dev affordance: `--demo` (optionally `--demo-left` / `--demo-right`)
        // fires a reminder shortly after launch so the overlay animation can be
        // exercised without waiting for the timer.
        let demoFlags: Set<String> = ["--demo", "--demo-left", "--demo-right"]
        if !demoFlags.isDisjoint(with: CommandLine.arguments) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.fireReminder()
            }
        }
        // Dev affordance: `--prefs` opens the Preferences window on launch.
        if CommandLine.arguments.contains("--prefs") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openPreferences()
            }
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = Self.makeIcon()
            button.image?.isTemplate = true // adapts to light/dark menu bar
            button.toolTip = "Puddles — stay hydrated"
        }

        let menu = NSMenu()
        menu.delegate = self

        countItem = NSMenuItem(title: countTitle(), action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Remind me now",
            action: #selector(remindNow),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Puddles",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self

        statusItem.menu = menu
    }

    // MARK: - Glass counter

    private func countTitle() -> String {
        let n = tracker.todayCount
        return "Today: \(n) \(n == 1 ? "glass" : "glasses") 💧"
    }

    private func refreshCountItem() {
        countItem?.title = countTitle()
    }

    /// Refresh the count (and roll over at midnight) each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        tracker.rolloverIfNeeded()
        refreshCountItem()
    }

    /// A small droplet glyph. Uses an SF Symbol when available, falling back to
    /// a hand-drawn pixel droplet so the app looks right without asset bundling.
    private static func makeIcon() -> NSImage {
        if let symbol = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Puddles") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            return symbol.withSymbolConfiguration(config) ?? symbol
        }
        return pixelDroplet()
    }

    /// A tiny pixel-art droplet drawn by hand (18x18), used as a fallback.
    private static func pixelDroplet() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()

        // Each row lists the filled pixel columns for a chunky droplet shape.
        let rows: [[Int]] = [
            [8, 9],
            [8, 9],
            [7, 8, 9, 10],
            [7, 8, 9, 10],
            [6, 7, 8, 9, 10, 11],
            [6, 7, 8, 9, 10, 11],
            [5, 6, 7, 8, 9, 10, 11, 12],
            [5, 6, 7, 8, 9, 10, 11, 12],
            [5, 6, 7, 8, 9, 10, 11, 12],
            [5, 6, 7, 8, 9, 10, 11, 12],
            [6, 7, 8, 9, 10, 11],
            [7, 8, 9, 10],
        ]
        let px: CGFloat = 1
        for (rowIndex, cols) in rows.enumerated() {
            let y = size.height - CGFloat(rowIndex + 3) * px
            for col in cols {
                NSBezierPath(rect: NSRect(x: CGFloat(col) * px, y: y, width: px, height: px)).fill()
            }
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Reminder timer

    private func startReminderTimer() {
        reminderTimer?.invalidate()
        let interval = TimeInterval(prefs.reminderIntervalMinutes * 60)
        reminderTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.reminderTick()
        }
        NSLog("Puddles: reminder timer set to \(prefs.reminderIntervalMinutes) min.")
    }

    /// A scheduled tick: only nudge the user if we're inside active hours.
    private func reminderTick() {
        guard prefs.isWithinActiveHours(Date()) else {
            NSLog("Puddles: outside active hours, skipping reminder.")
            return
        }
        fireReminder()
    }

    private func fireReminder() {
        NSLog("💧 Puddles: time to drink some water! 🐱")

        if prefs.soundEnabled {
            NSSound(named: "Pop")?.play()
        }

        // Only one overlay at a time — replace any that's currently on screen.
        overlay?.dismissImmediately()

        let controller = ReminderOverlayController()
        // Testing hooks: --demo-left / --demo-right force the entry edge.
        if CommandLine.arguments.contains("--demo-left") {
            controller.forcedSideLeft = true
        } else if CommandLine.arguments.contains("--demo-right") {
            controller.forcedSideLeft = false
        }
        controller.onCatClicked = { [weak self] in
            self?.tracker.increment()
            self?.refreshCountItem()
        }
        controller.onFinished = { [weak self] in self?.overlay = nil }
        overlay = controller
        controller.show()
    }

    // MARK: - Actions

    @objc private func remindNow() {
        // Manual trigger always fires, regardless of active hours.
        fireReminder()
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let hosting = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Puddles Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            prefsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
