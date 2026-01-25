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
        print("[MacConnection] Disconnected")
    }

    func sendCommand(_ command: String, source: BridgeCoordinator.CommandSource = .phone) {
        guard let mac = connectedMac else { return }

        let payload: [String: String] = [
            "command": command,
            "source": source.rawValue
        ]

        guard let data = try? JSONEncoder().encode(payload) else { return }

        do {
            try session.send(data, toPeers: [mac], with: .reliable)
            print("[MacConnection] Sent: \(command) (from \(source.rawValue))")
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
        // Ta emot ACK från Mac
        if let ack = String(data: data, encoding: .utf8) {
            print("[MacConnection] ACK from Mac: \(ack)")
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
