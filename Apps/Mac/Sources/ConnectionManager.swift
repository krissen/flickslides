import Foundation
import MultipeerConnectivity
import Combine
import FlickSlidesKit

/// Hanterar MultipeerConnectivity med iOS.
final class ConnectionManager: NSObject, ObservableObject {
    private let serviceType = FlickSlidesConstants.multipeerServiceType
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private let keyboardSimulator: KeyboardSimulator

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var connectedPeerName: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var lastCommandSource: String?  // "watch" eller "phone"

    private var authorizedPeerID: MCPeerID?

    init(keyboardSimulator: KeyboardSimulator = KeyboardSimulator()) {
        self.keyboardSimulator = keyboardSimulator
        super.init()
        setupMultipeer()
    }

    private func setupMultipeer() {
        let deviceName = Host.current().localizedName ?? "Mac"
        peerID = MCPeerID(displayName: deviceName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
    }

    func startAdvertising() {
        advertiser.startAdvertisingPeer()
        connectionState = .searching
        print("[ConnectionManager] Started advertising as: \(peerID.displayName)")
    }

    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
    }
}

// MARK: - MCSessionDelegate

extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.authorizedPeerID = peerID
                self.connectionState = .connected(deviceName: peerID.displayName)
                self.connectedPeerName = peerID.displayName
                print("[ConnectionManager] Connected to: \(peerID.displayName)")

            case .notConnected:
                if peerID == self.authorizedPeerID {
                    self.authorizedPeerID = nil
                    self.connectionState = .disconnected
                    self.connectedPeerName = nil
                }
                print("[ConnectionManager] Disconnected from: \(peerID.displayName)")

            case .connecting:
                self.connectionState = .connecting

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Säkerhet: endast acceptera från godkänd peer
        guard peerID == authorizedPeerID else {
            print("[ConnectionManager] Rejected command from unauthorized peer: \(peerID.displayName)")
            return
        }

        // Försök parsa som JSON först (nytt format)
        var commandString: String
        var source: String = "phone"

        if let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let cmd = payload["command"] {
            commandString = cmd
            source = payload["source"] ?? "phone"
        } else if let plainCommand = String(data: data, encoding: .utf8) {
            // Fallback för gammalt format
            commandString = plainCommand
        } else {
            print("[ConnectionManager] Invalid command data")
            return
        }

        guard let command = PresentationCommand(rawValue: commandString) else {
            print("[ConnectionManager] Unknown command: \(commandString)")
            return
        }

        print("[ConnectionManager] Received: \(command.rawValue) from \(source)")

        DispatchQueue.main.async {
            self.lastCommand = command.rawValue
            self.lastCommandSource = source
        }

        let success = keyboardSimulator.handleCommand(command)

        // Skicka ACK tillbaka
        let ack = CommandAck(command: command, success: success)
        if let ackData = try? JSONEncoder().encode(ack) {
            try? session.send(ackData, toPeers: [peerID], with: .reliable)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName: String, fromPeer: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                   didReceiveInvitationFromPeer peerID: MCPeerID,
                   withContext context: Data?,
                   invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Acceptera anslutning
        invitationHandler(true, session)
        print("[ConnectionManager] Accepted invitation from: \(peerID.displayName)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[ConnectionManager] Failed to start advertising: \(error)")
        DispatchQueue.main.async {
            self.connectionState = .error(error.localizedDescription)
        }
    }
}
