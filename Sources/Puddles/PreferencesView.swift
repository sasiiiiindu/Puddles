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

            Section("Character") {
                HStack(spacing: 10) {
                    ForEach(Character.all) { character in
                        characterCard(id: character.id, name: character.displayName) {
                            CharacterPreviewView(character: character)
                        }
                    }
                    characterCard(id: Character.surpriseID, name: "Surprise me") {
                        Image(systemName: "shuffle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Surprise me picks a random character for each reminder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Play a sound when the character appears", isOn: $prefs.soundEnabled)
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 560)
    }

    /// A selectable card: an (animated) preview above the character's name,
    /// highlighted when it is the current selection.
    private func characterCard<Preview: View>(
        id: String, name: String, @ViewBuilder preview: () -> Preview
    ) -> some View {
        let isSelected = prefs.characterID == id
        return Button {
            prefs.characterID = id
        } label: {
            VStack(spacing: 6) {
                preview()
                    .frame(width: 48, height: 48)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1)
            )
            // Transparent regions aren't hittable by default — make the whole
            // card (padding, clear background) accept the click.
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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

/// A small animated preview of a character: wraps `SpriteView` (the same
/// pixel-perfect renderer the overlay uses) playing the walk cycle in place.
private struct CharacterPreviewView: NSViewRepresentable {
    let character: Character

    func makeNSView(context: Context) -> SpriteView {
        let view = SpriteView()
        view.play(sheet: character.walkSheet(), fps: character.walkFPS)
        return view
    }

    func updateNSView(_ nsView: SpriteView, context: Context) {}

    static func dismantleNSView(_ nsView: SpriteView, coordinator: ()) {
        nsView.stopAnimating()
    }
}
