import Foundation

/// Tracks how many glasses were "drunk" today (each cat click counts as one).
/// The count is persisted and automatically resets when the date rolls over.
final class HydrationTracker: ObservableObject {

    static let shared = HydrationTracker()

    @Published private(set) var todayCount = 0

    private let defaults = UserDefaults.standard
    private enum Key {
        static let day = "hydration.day"
        static let count = "hydration.count"
    }

    private var dayKey: String

    private init() {
        dayKey = defaults.string(forKey: Key.day) ?? ""
        todayCount = defaults.integer(forKey: Key.count)
        rolloverIfNeeded()
    }

    private static func currentDayKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Reset the count if the calendar day has changed since it was last saved.
    func rolloverIfNeeded() {
        let today = Self.currentDayKey()
        guard today != dayKey else { return }
        dayKey = today
        todayCount = 0
        defaults.set(dayKey, forKey: Key.day)
        defaults.set(0, forKey: Key.count)
    }

    /// Record one glass drunk.
    func increment() {
        rolloverIfNeeded()
        todayCount += 1
        defaults.set(todayCount, forKey: Key.count)
    }
}
