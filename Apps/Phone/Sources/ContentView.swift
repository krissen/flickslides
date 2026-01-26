import SwiftUI
import FlickSlidesKit

struct ContentView: View {
    @StateObject private var watchSession = WatchSessionManager.shared
    @StateObject private var macConnection = MacConnectionManager.shared
    @StateObject private var coordinator = BridgeCoordinator.shared
    @State private var showCalibration = false

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

                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(macConnection.connectedMac != nil ? .green : .gray)
                        Text("Mac")
                        Spacer()
                        Text(macStatusText)
                            .foregroundColor(.secondary)
                    }
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

                        Spacer()

                        Button(action: { sendManualCommand("BLACKOUT") }) {
                            Image(systemName: "rectangle.fill")
                                .font(.title)
                        }
                        .buttonStyle(.borderless)
                        .disabled(macConnection.connectedMac == nil)
                        .tint(.orange)

                        Spacer()

                        Button(action: { sendManualCommand("NEXT") }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.largeTitle)
                        }
                        .buttonStyle(.borderless)
                        .disabled(macConnection.connectedMac == nil)
                    }
                    .padding(.vertical)
                }

                // Kalibrering
                Section("Gestkalibrering") {
                    Button {
                        showCalibration = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.wave.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Kalibrera gester")
                                Text("Anpassa gestdetektering")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!watchSession.isWatchReachable)
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
                                Text(log.status)
                                    .font(.caption)
                            }
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
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleConnection) {
                        Image(systemName: macConnection.connectedMac != nil ? "wifi.slash" : "wifi")
                    }
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
