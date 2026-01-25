# iOS-kommunikation: Watch → iPhone → Mac

## Sammanfattning

iPhone-appen fungerar som osynlig brygga mellan Apple Watch och Mac med två kommunikationslager:

1. **Watch → iPhone:** WatchConnectivity (WCSession) - latens ~50-200ms
2. **iPhone → Mac:** MultipeerConnectivity (MCSession) - latens ~10-50ms
3. **Total förväntad latens:** 60-250ms (uppfyller kravet på <500ms)

---

## 1. WatchConnectivity (Watch → iPhone)

### API-översikt

```swift
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var isWatchReachable = false
    @Published var lastCommand: String?
    @Published var lastCommandTimestamp: Date?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Återaktivera för att stödja Watch-byte
        WCSession.default.activate()
    }

    /// Tar emot meddelanden från Watch (realtid, kräver att iOS är reachable)
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        guard let command = message["command"] as? String else { return }

        let timestamp = Date()
        DispatchQueue.main.async {
            self.lastCommand = command
            self.lastCommandTimestamp = timestamp
        }

        // Vidarebefordra till Mac
        BridgeCoordinator.shared.forwardToMac(command: command, timestamp: timestamp)
    }

    /// Tar emot meddelanden med reply handler (för latenslogging)
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = message["command"] as? String else {
            replyHandler(["error": "Invalid command"])
            return
        }

        let receiveTimestamp = Date()

        // Vidarebefordra till Mac
        BridgeCoordinator.shared.forwardToMac(command: command, timestamp: receiveTimestamp)

        // Bekräfta till Watch
        replyHandler([
            "ack": command,
            "timestamp": receiveTimestamp.timeIntervalSince1970
        ])
    }
}
```

### Kritiskt: Bakgrundsbeteende

**`sendMessage` fungerar ENDAST om:**
- iOS-appen är i förgrund, ELLER
- iOS-appen nyligen har varit aktiv (inom ~10-15 sekunder)

**`sendMessage` fungerar INTE om:**
- iOS-appen är terminerad
- iOS-appen har varit i djup bakgrund länge

**Lösning:** Kräv att iOS-appen körs i förgrund under presentation med:
```swift
UIApplication.shared.isIdleTimerDisabled = true
```

---

## 2. MultipeerConnectivity (iPhone → Mac)

### API-översikt

```swift
import MultipeerConnectivity

class MacConnectionManager: NSObject, ObservableObject {
    static let shared = MacConnectionManager()

    private let serviceType = "flickslides-ctrl"  // Max 15 tecken, lowercase + hyphen
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!

    @Published var connectedMac: MCPeerID?
    @Published var availableMacs: [MCPeerID] = []
    @Published var connectionState: ConnectionState = .disconnected

    private override init() {
        super.init()

        peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID,
                           securityIdentity: nil,
                           encryptionPreference: .required)
        session.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
        connectionState = .searching
    }

    func stopBrowsing() {
        browser.stopBrowsingForPeers()
    }

    func connect(to mac: MCPeerID) {
        connectionState = .connecting
        browser.invitePeer(mac, to: session, withContext: nil, timeout: 10)
    }

    func disconnect() {
        session.disconnect()
        connectedMac = nil
        connectionState = .disconnected
    }

    func sendCommand(_ command: String) {
        guard let mac = connectedMac,
              let data = command.data(using: .utf8) else { return }

        do {
            try session.send(data, toPeers: [mac], with: .reliable)
            print("[\(Date())] Sent to Mac: \(command)")
        } catch {
            print("Failed to send: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate

extension MacConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectedMac = peerID
                self.connectionState = .connected(deviceName: peerID.displayName)
                self.stopBrowsing()
                print("Connected to Mac: \(peerID.displayName)")

            case .notConnected:
                if self.connectedMac == peerID {
                    self.connectedMac = nil
                    self.connectionState = .disconnected
                    // Försök återansluta
                    self.startBrowsing()
                }

            case .connecting:
                self.connectionState = .connecting

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Ta emot ACK från Mac
        if let ack = String(data: data, encoding: .utf8) {
            print("[\(Date())] ACK from Mac: \(ack)")
        }
    }

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {}

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MacConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.availableMacs.contains(peerID) {
                self.availableMacs.append(peerID)
                print("Found Mac: \(peerID.displayName)")
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availableMacs.removeAll { $0 == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing: \(error)")
        connectionState = .error(error.localizedDescription)
    }
}
```

---

## 3. BridgeCoordinator

```swift
import Foundation

class BridgeCoordinator: ObservableObject {
    static let shared = BridgeCoordinator()

    @Published var commandLog: [(command: String, timestamp: Date, status: String)] = []

    private init() {}

    func forwardToMac(command: String, timestamp: Date) {
        let macManager = MacConnectionManager.shared

        guard macManager.connectedMac != nil else {
            addLog(command: command, timestamp: timestamp, status: "❌ Ingen Mac ansluten")
            return
        }

        macManager.sendCommand(command)
        addLog(command: command, timestamp: timestamp, status: "✓ Skickat")
    }

    private func addLog(command: String, timestamp: Date, status: String) {
        DispatchQueue.main.async {
            self.commandLog.insert((command, timestamp, status), at: 0)
            // Behåll max 50 loggar
            if self.commandLog.count > 50 {
                self.commandLog.removeLast()
            }
        }
    }
}
```

---

## 4. SwiftUI-gränssnitt

```swift
import SwiftUI

struct ContentView: View {
    @ObservedObject var watchSession = WatchSessionManager.shared
    @ObservedObject var macConnection = MacConnectionManager.shared
    @ObservedObject var coordinator = BridgeCoordinator.shared

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
                        Image(systemName: macConnection.connectedMac != nil ? "desktopcomputer" : "desktopcomputer")
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
                        .disabled(macConnection.connectedMac == nil)

                        Spacer()

                        Button(action: { sendManualCommand("NEXT") }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.largeTitle)
                        }
                        .disabled(macConnection.connectedMac == nil)
                    }
                    .padding(.vertical)
                }

                // Kommandologg
                Section("Senaste kommandon") {
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
            .navigationTitle("FlickSlides")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleConnection) {
                        Image(systemName: macConnection.connectedMac != nil ? "wifi.slash" : "wifi")
                    }
                }
            }
        }
        .onAppear {
            macConnection.startBrowsing()
            // Förhindra skärmsläckning under presentation
            UIApplication.shared.isIdleTimerDisabled = true
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
        coordinator.forwardToMac(command: command, timestamp: Date())
    }

    private func toggleConnection() {
        if macConnection.connectedMac != nil {
            macConnection.disconnect()
        } else {
            macConnection.startBrowsing()
        }
    }
}
```

---

## 5. Info.plist-krav

```xml
<!-- Lokalt nätverkstillstånd -->
<key>NSLocalNetworkUsageDescription</key>
<string>FlickSlides behöver tillgång till lokalt nätverk för att styra presentationer på din Mac.</string>

<!-- Bonjour-tjänster -->
<key>NSBonjourServices</key>
<array>
    <string>_flickslides-ctrl._tcp</string>
    <string>_flickslides-ctrl._udp</string>
</array>

<!-- Bakgrundslägen (om nödvändigt) -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## Latensförväntningar

| Segment | Bästa fall | Normalt | Värsta fall |
|---------|------------|---------|-------------|
| Watch → iOS (WCSession) | 50ms | 100-150ms | 300ms |
| iOS → Mac (MCSession) | 10ms | 20-50ms | 100ms |
| **Totalt** | **60ms** | **120-200ms** | **400ms** |

**Slutsats:** Total latens håller sig väl under kravet på 500ms i normala fall.

---

## Risker och åtgärder

| Risk | Sannolikhet | Konsekvens | Åtgärd |
|------|-------------|------------|--------|
| iOS termineras i bakgrund | Medel | Hög | Kräv förgrund + `isIdleTimerDisabled` |
| Wi-Fi-avbrott | Låg | Medel | MC faller tillbaka till Bluetooth |
| Nätverksbehörighet nekas | Låg | Hög | Tydlig förklaringstext i UI |
| Flera Mac-datorer | Låg | Låg | Användaren väljer manuellt |

---

## Öppna frågor

1. **Accepterar vi kravet på att iOS-appen måste vara i förgrund under presentation?**
   - Rekommendation: Ja, det är en rimlig kompromiss för tillförlitlighet.

2. **Behövs verifieringskod vid parkoppling?**
   - Rekommendation: Nej i v1, lokal nätverksavgränsning räcker.

3. **Automatisk återanslutning vid avbrott?**
   - Rekommendation: Ja, implementera i v1.

---

## Nästa steg

1. Skapa iOS-app-projekt i Xcode
2. Integrera FlickSlidesKit som dependency
3. Implementera prototypkoden ovan
4. Koordinera med macOS-utvecklaren för advertiser-sidan
5. Latenstest med QA

---

*Rapport skapad: 2025-01-25*
*Status: KLAR*
