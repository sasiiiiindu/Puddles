import SwiftUI

/// The Preferences window contents. Observes the shared `Preferences`, so edits
/// persist and apply live (e.g. changing the interval reschedules the timer).
struct PreferencesView: View {

    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section("Reminders") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Reminder interval")
                        Spacer()
                        Text(intervalLabel).foregroundStyle(.secondary)
                    }
                    Slider(value: intervalBinding, in: 15...180, step: 5) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("15m").font(.caption)
                    } maximumValueLabel: {
                        Text("3h").font(.caption)
                    }
                }
            }

            Section("Active hours") {
                DatePicker("Start", selection: timeBinding(\.activeStartMinutes),
                           displayedComponents: .hourAndMinute)
                DatePicker("End", selection: timeBinding(\.activeEndMinutes),
                           displayedComponents: .hourAndMinute)
                Text("No reminders fire outside these hours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Play a sound when the cat appears", isOn: $prefs.soundEnabled)
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 430)
    }

    // MARK: - Derived bindings & labels

    private var intervalLabel: String {
        let minutes = prefs.reminderIntervalMinutes
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours) hr" : "\(hours) hr \(rem) min"
    }

    private var intervalBinding: Binding<Double> {
        Binding(
            get: { Double(prefs.reminderIntervalMinutes) },
            set: { prefs.reminderIntervalMinutes = Int($0) }
        )
    }

    /// Bridges a "minutes since midnight" setting to a `Date` for the picker.
    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<Preferences, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = prefs[keyPath: keyPath]
                return Calendar.current.startOfDay(for: Date())
                    .addingTimeInterval(TimeInterval(minutes * 60))
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                prefs[keyPath: keyPath] = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }
}
