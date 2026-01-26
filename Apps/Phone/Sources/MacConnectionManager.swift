import Foundation
import MultipeerConnectivity
import FlickSlidesKit

/// Hanterar MultipeerConnectivity med Mac.
final class MacConnectionManager: NSObject, ObservableObject {
    static let shared = MacConnectionManager()

    private let serviceType = FlickSlidesConstants.multipeerServiceType
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!

    @Published var connectedMac: MCPeerID?
    @Published var availableMacs: [MCPeerID] = []
    @Published var connectionState: ConnectionState = .disconnected

    /// Tillgängliga presentationsappar på Mac
    @Published var availableApps: [AppInfo] = []

    /// Vald app för kommandon
    @Published var selectedApp: AppInfo?

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
        print("[MacConnection] Started browsing for peers")
    }

    func stopBrowsing() {
        browser.stopBrowsingForPeers()
    }

    func connect(to mac: MCPeerID) {
        connectionState = .connecting
        browser.invitePeer(mac, to: session, withContext: nil, timeout: 10)
        print("[MacConnection] Inviting: \(mac.displayName)")
    }

    func disconnect() {
        session.disconnect()
        connectedMac = nil
        connectionState = .disconnected
        availableApps = []
        selectedApp = nil
        print("[MacConnection] Disconnected")
    }

    /// Välj målapp för kommandon
    func selectApp(_ app: AppInfo) {
        guard let mac = connectedMac else { return }

        selectedApp = app
        let message = AppMessage.selectApp(app.id)

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [mac], with: .reliable)
            print("[MacConnection] Selected app: \(app.name)")
        } catch {
            print("[MacConnection] Failed to select app: \(error)")
        }
    }

    /// Avmarkera vald app
    func clearSelectedApp() {
        selectedApp = nil
    }

    func sendCommand(_ command: String, source: BridgeCoordinator.CommandSource = .phone) {
        guard let mac = connectedMac else { return }

        // Använd AppMessage.command för att inkludera målapp
        let message = AppMessage.command(command, source: source.rawValue, targetApp: selectedApp?.id)

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [mac], with: .reliable)
            print("[MacConnection] Sent: \(command) (from \(source.rawValue), target: \(selectedApp?.name ?? "any"))")
        } catch {
            print("[MacConnection] Failed to send: \(error)")
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
                print("[MacConnection] Connected to: \(peerID.displayName)")

            case .notConnected:
                if self.connectedMac == peerID {
                    self.connectedMac = nil
                    self.connectionState = .disconnected
                    // Försök återansluta automatiskt
                    self.startBrowsing()
                }
                print("[MacConnection] Disconnected from: \(peerID.displayName)")

            case .connecting:
                self.connectionState = .connecting

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Försök parsa som AppMessage
        if let message = try? JSONDecoder().decode(AppMessage.self, from: data) {
            handleAppMessage(message)
            return
        }

        // Ta emot ACK från Mac (legacy)
        if let ack = String(data: data, encoding: .utf8) {
            print("[MacConnection] ACK from Mac: \(ack)")
        }
    }

    private func handleAppMessage(_ message: AppMessage) {
        switch message {
        case .appList(let apps):
            DispatchQueue.main.async {
                self.availableApps = apps
                print("[MacConnection] Received app list: \(apps.map { $0.name })")

                // Om vald app inte längre finns i listan, rensa valet
                if let selected = self.selectedApp,
                   !apps.contains(where: { $0.id == selected.id }) {
                    self.selectedApp = nil
                    print("[MacConnection] Selected app no longer available, cleared selection")
                }

                // Auto-välj om endast en app finns och ingen är vald
                if self.selectedApp == nil && apps.count == 1 {
                    self.selectApp(apps[0])
                }
            }

        case .selectApp, .command:
            // iPhone skickar dessa, tar inte emot
            print("[MacConnection] Received unexpected message type")
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
                print("[MacConnection] Found: \(peerID.displayName)")
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.availableMacs.removeAll { $0 == peerID }
            print("[MacConnection] Lost: \(peerID.displayName)")
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        print("[MacConnection] Failed to start browsing: \(error)")
        connectionState = .error(error.localizedDescription)
    }
}
