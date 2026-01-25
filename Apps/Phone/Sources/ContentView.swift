import SwiftUI

struct ContentView: View {
    @StateObject private var watchSession = WatchSessionManager.shared
    @StateObject private var macConnection = MacConnectionManager.shared
    @StateObject private var coordinator = BridgeCoordinator.shared

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
