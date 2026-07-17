import Foundation
import Combine
import ServiceManagement

/// User-configurable settings, persisted in `UserDefaults` and published so the
/// SwiftUI preferences window and the app delegate can react live.
final class Preferences: ObservableObject {

    static let shared = Preferences()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let interval = "reminderIntervalMinutes"
        static let activeStart = "activeStartMinutes"
        static let activeEnd = "activeEndMinutes"
        static let sound = "soundEnabled"
        static let character = "characterID"
    }

    /// Minutes between reminders (15 min … 3 hours).
    @Published var reminderIntervalMinutes: Int {
        didSet { defaults.set(reminderIntervalMinutes, forKey: Key.interval) }
    }

    /// Active window as minutes since midnight; no reminders fire outside it.
    @Published var activeStartMinutes: Int {
        didSet { defaults.set(activeStartMinutes, forKey: Key.activeStart) }
    }
    @Published var activeEndMinutes: Int {
        didSet { defaults.set(activeEndMinutes, forKey: Key.activeEnd) }
    }

    /// Play a soft sound when the character appears.
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.sound) }
    }

    /// Which character walks in: a `Character.id`, or `Character.surpriseID`
    /// to pick randomly per reminder. Resolved via `Character.resolve` each
    /// time a reminder fires, so changes apply without restarting.
    @Published var characterID: String {
        didSet { defaults.set(characterID, forKey: Key.character) }
    }

    /// Whether the app is registered to launch at login (backed by SMAppService,
    /// whose status is the source of truth — not UserDefaults).
    @Published var launchAtLogin: Bool = false {
        didSet {
            guard !suppressLaunchApply else { return }
            applyLaunchAtLogin()
        }
    }
    private var suppressLaunchApply = false

    private init() {
        reminderIntervalMinutes = defaults.object(forKey: Key.interval) as? Int ?? 60
        activeStartMinutes = defaults.object(forKey: Key.activeStart) as? Int ?? (9 * 60)   // 09:00
        activeEndMinutes = defaults.object(forKey: Key.activeEnd) as? Int ?? (21 * 60)       // 21:00
        soundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        characterID = defaults.string(forKey: Key.character) ?? Character.puddles.id

        // Reflect the real login-item status without triggering a register call.
        suppressLaunchApply = true
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        suppressLaunchApply = false
    }

    // MARK: - Active hours

    /// True if `date`'s time-of-day falls within the active window. Supports an
    /// overnight window (end earlier than start).
    func isWithinActiveHours(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let t = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let start = activeStartMinutes, end = activeEndMinutes
        if start == end { return true }               // full day
        if start < end { return t >= start && t < end }
        return t >= start || t < end                  // overnight wrap
    }

    // MARK: - Launch at login

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Puddles: launch-at-login change failed: \(error.localizedDescription)")
            // Revert the toggle to the actual system state.
            suppressLaunchApply = true
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            suppressLaunchApply = false
        }
    }
}
