import SwiftUI
import FlickSlidesKit

struct ContentView: View {
    @StateObject private var watchSession = WatchSessionManager.shared
    @StateObject private var macConnection = MacConnectionManager.shared
    @StateObject private var coordinator = BridgeCoordinator.shared
    @State private var showCalibration = false

    // Kalibrering är valfri - användare kan välja att använda standardvärden
    @AppStorage("useCalibration", store: UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides"))
    private var useCalibration = true

    /// Kontrollerar om kalibrering har utförts (mallar finns)
    private var hasCalibration: Bool {
        let defaults = UserDefaults(suiteName: "group.com.kristianniemi.FlickSlides") ?? .standard
        return defaults.data(forKey: "gestureTemplates") != nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Status-sektion
                Section("Anslutningsstatus") {
                    HStack {
                        Image(systemName: watchSession.isWatchReachable ? "applewatch" : "applewatch.slash")
                            .foregroundColor(watchSession.isWatchReachable ? .green : .gray)
                        Text("Apple Watch")
                        Spacer()
                        Text(watchSession.isWatchReachable ? "Ansluten" : "Ej nåbar")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Apple Watch: \(watchSession.isWatchReachable ? "ansluten" : "ej nåbar")")

                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(macConnection.connectedMac != nil ? .green : .gray)
                        Text("Mac")
                        Spacer()
                        Text(macStatusText)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Mac: \(macStatusText)")
                }

                // Mac-val
                if macConnection.connectedMac == nil {
                    Section("Välj Mac") {
                        if macConnection.availableMacs.isEmpty {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Söker efter Mac-datorer...")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(macConnection.availableMacs, id: \.self) { mac in
                                Button(action: { macConnection.connect(to: mac) }) {
                                    HStack {
                                        Image(systemName: "desktopcomputer")
                                        Text(mac.displayName)
                                    }
                                }
                            }
                        }
                    }
                }

                // App-val (visas endast när ansluten till Mac)
                if macConnection.connectedMac != nil {
                    Section("Målapp") {
                        if macConnection.availableApps.isEmpty {
                            HStack {
                                Image(systemName: "app.dashed")
                                    .foregroundColor(.secondary)
                                Text("Ingen presentationsapp igång")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Picker(selection: Binding(
                                get: { macConnection.selectedApp?.id ?? "" },
                                set: { newId in
                                    if let app = macConnection.availableApps.first(where: { $0.id == newId }) {
                                        macConnection.selectApp(app)
                                    }
                                }
                            ), label: Label("App", systemImage: "app.fill")) {
                                Text("Alla appar").tag("")
                                ForEach(macConnection.availableApps) { app in
                                    Label {
                                        Text(app.name)
                                    } icon: {
                                        Image(systemName: app.isActive ? "circle.fill" : "circle")
                                            .foregroundColor(app.isActive ? .green : .secondary)
                                    }
                                    .tag(app.id)
                                }
                            }
                        }
                    }
                }

                // Manuell kontroll
                Section("Manuell kontroll") {
                    HStack(spacing: 20) {
                        Button(action: { sendManualCommand("PREV") }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.largeTitle)
                        }
                        .buttonStyle(.borderless)
                        .disabled(macConnection.connectedMac == nil)
                        .accessibilityLabel("Föregående slide")
                        .accessibilityHint("Gå till föregående slide i presentationen")

                        Spacer()

                        Button(action: { sendManualCommand("BLACKOUT") }) {
                            Image(systemName: "rectangle.fill")
                                .font(.title)
                        }
                        .buttonStyle(.borderless)
                        .disabled(macConnection.connectedMac == nil)
                        .tint(.orange)
                        .accessibilityLabel("Svart skärm")
                        .accessibilityHint("Växla svart skärm i presentationen")

                        Spacer()

                        Button(action: { sendManualCommand("NEXT") }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.largeTitle)
                        }
                        .buttonStyle(.borderless)
                        .disabled(macConnection.connectedMac == nil)
                        .accessibilityLabel("Nästa slide")
                        .accessibilityHint("Gå till nästa slide i presentationen")
                    }
                    .padding(.vertical)
                }

                // Kalibrering (valfritt)
                Section {
                    Toggle(isOn: $useCalibration) {
                        VStack(alignment: .leading) {
                            Text("Använd personliga gester")
                            Text(hasCalibration ? "Kalibrering aktiv" : "Använder standardvärden")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!hasCalibration)

                    Button {
                        showCalibration = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.wave.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(hasCalibration ? "Kalibrera om" : "Kalibrera gester")
                                Text("Valfritt – ~30 sek")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!watchSession.isWatchReachable)
                } header: {
                    Text("Finjustering")
                } footer: {
                    Text("Gester fungerar direkt utan kalibrering. Kalibrera endast om du har problem.")
                }

                // Kommandologg
                Section("Senaste kommandon") {
                    if coordinator.commandLog.isEmpty {
                        Text("Inga kommandon ännu")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(coordinator.commandLog.prefix(10), id: \.timestamp) { log in
                            HStack {
                                Text(log.command)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                if let latencyMs = log.latencyMs {
                                    Text("\(latencyMs)ms")
                                        .font(.caption)
                                        .foregroundColor(latencyMs < 500 ? .green : .orange)
                                }
                                Text(log.status)
                                    .font(.caption)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(log.command): \(log.status)\(log.latencyMs.map { ", latens \($0) millisekunder" } ?? "")")
                        }
                    }
                }
            }
            .navigationTitle("FlickSlides")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Inställningar")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleConnection) {
                        Image(systemName: macConnection.connectedMac != nil ? "wifi.slash" : "wifi")
                    }
                    .accessibilityLabel(macConnection.connectedMac != nil ? "Koppla från Mac" : "Sök efter Mac")
                }
            }
        }
        .onAppear {
            macConnection.startBrowsing()
        }
        .sheet(isPresented: $showCalibration) {
            PhoneCalibrationView()
        }
    }

    private var macStatusText: String {
        switch macConnection.connectionState {
        case .searching:
            return "Söker..."
        case .connecting:
            return "Ansluter..."
        case .connected(let name):
            return name
        case .disconnected:
            return "Ej ansluten"
        case .error(let msg):
            return "Fel: \(msg)"
        }
    }

    private func sendManualCommand(_ command: String) {
        coordinator.forwardToMac(command: command, timestamp: Date(), source: .phone)
    }

    private func toggleConnection() {
        if macConnection.connectedMac != nil {
            macConnection.disconnect()
        } else {
            macConnection.startBrowsing()
        }
    }
}

#Preview {
    ContentView()
}
