import SwiftUI

struct SettingsView: View {
    // MARK: - App Group

    private static let appGroupID = "group.com.kristianniemi.FlickSlides"

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let accelerationThreshold = "accelerationThreshold"
        static let rotationThreshold = "rotationThreshold"
        static let gestureDebounceInterval = "gestureDebounceInterval"
        static let watchOnRightWrist = "watchOnRightWrist"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let accelerationThreshold: Double = 1.5
        static let rotationThreshold: Double = 30.0
        static let gestureDebounceInterval: Double = 1.0
    }

    // MARK: - State

    @State private var accelerationThreshold: Double
    @State private var rotationThreshold: Double
    @State private var debounceInterval: Double
    @State private var watchOnRightWrist: Bool

    private let defaults: UserDefaults

    // MARK: - Init

    init() {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        self.defaults = defaults

        let accel = defaults.object(forKey: Keys.accelerationThreshold) as? Double
            ?? Defaults.accelerationThreshold
        let rot = defaults.object(forKey: Keys.rotationThreshold) as? Double
            ?? Defaults.rotationThreshold
        let debounce = defaults.object(forKey: Keys.gestureDebounceInterval) as? Double
            ?? Defaults.gestureDebounceInterval
        let rightWrist = defaults.object(forKey: Keys.watchOnRightWrist) as? Bool ?? true

        _accelerationThreshold = State(initialValue: accel)
        _rotationThreshold = State(initialValue: rot)
        _debounceInterval = State(initialValue: debounce)
        _watchOnRightWrist = State(initialValue: rightWrist)
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Klockan sitter på", selection: $watchOnRightWrist) {
                    Text("Vänster").tag(false)
                    Text("Höger").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: watchOnRightWrist) { _, newValue in
                    defaults.set(newValue, forKey: Keys.watchOnRightWrist)
                }
            } header: {
                Text("Handled")
            } footer: {
                Text("Ändringen aktiveras automatiskt inom några sekunder.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Accelerationströskel")
                        Spacer()
                        Text(String(format: "%.1f g", accelerationThreshold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $accelerationThreshold,
                        in: 0.5...3.0,
                        step: 0.1
                    ) {
                        Text("Acceleration")
                    } onEditingChanged: { editing in
                        if !editing {
                            saveAccelerationThreshold()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rotationströskel")
                        Spacer()
                        Text(String(format: "%.0f°/s", rotationThreshold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $rotationThreshold,
                        in: 10...90,
                        step: 5
                    ) {
                        Text("Rotation")
                    } onEditingChanged: { editing in
                        if !editing {
                            saveRotationThreshold()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Debounce-intervall")
                        Spacer()
                        Text(String(format: "%.1f s", debounceInterval))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $debounceInterval,
                        in: 0.5...3.0,
                        step: 0.1
                    ) {
                        Text("Debounce")
                    } onEditingChanged: { editing in
                        if !editing {
                            saveDebounceInterval()
                        }
                    }
                }
            } header: {
                Text("Gesttrösklar")
            } footer: {
                Text("Justera känsligheten för att identifiera gester från Apple Watch. Lägre värden ger känsligare respons.")
            }

            Section {
                Button(action: resetToDefaults) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Återställ till standardvärden")
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Standardvärden")
                        .font(.headline)
                    Text("Acceleration: \(String(format: "%.1f g", Defaults.accelerationThreshold))")
                    Text("Rotation: \(String(format: "%.0f°/s", Defaults.rotationThreshold))")
                    Text("Debounce: \(String(format: "%.1f s", Defaults.gestureDebounceInterval))")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Inställningar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Save Methods

    private func saveAccelerationThreshold() {
        defaults.set(accelerationThreshold, forKey: Keys.accelerationThreshold)
    }

    private func saveRotationThreshold() {
        defaults.set(rotationThreshold, forKey: Keys.rotationThreshold)
    }

    private func saveDebounceInterval() {
        defaults.set(debounceInterval, forKey: Keys.gestureDebounceInterval)
    }

    private func resetToDefaults() {
        accelerationThreshold = Defaults.accelerationThreshold
        rotationThreshold = Defaults.rotationThreshold
        debounceInterval = Defaults.gestureDebounceInterval

        defaults.set(accelerationThreshold, forKey: Keys.accelerationThreshold)
        defaults.set(rotationThreshold, forKey: Keys.rotationThreshold)
        defaults.set(debounceInterval, forKey: Keys.gestureDebounceInterval)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
