import AppKit
import Foundation
import MultipeerConnectivity
import Combine
import FlickSlidesKit
import UserNotifications

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

    /// Vald app som mål för kommandon (bundle identifier)
    @Published var selectedAppBundleId: String?

    private var authorizedPeerID: MCPeerID?
    private var appListTimer: Timer?

    /// Betrodda peer-namn (sparas i UserDefaults)
    @Published private(set) var trustedPeers: Set<String> = []

    /// Väntande anslutningsförfrågan
    @Published private(set) var pendingInvitation: PendingInvitation?

    struct PendingInvitation {
        let peerName: String
        let handler: (Bool) -> Void
    }

    private let trustedPeersKey = "FlickSlides.trustedPeers"

    /// Bundle identifiers för appar som stöds för presentation
    private let presentationAppBundleIds: Set<String> = [
        "com.apple.iWork.Keynote",
        "com.microsoft.PowerPoint",
        "com.apple.Preview",
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.adobe.Reader",              // Adobe Acrobat Reader (äldre)
        "com.adobe.Acrobat",             // Adobe Acrobat (nyare)
        "com.adobe.Acrobat.Pro",         // Adobe Acrobat Pro
        "com.adobe.AcrobatReader",       // Alternativt namn
        "net.sourceforge.skim-app.skim"  // Skim PDF viewer
    ]

    init(keyboardSimulator: KeyboardSimulator = KeyboardSimulator()) {
        self.keyboardSimulator = keyboardSimulator
        super.init()
        loadTrustedPeers()
        setupMultipeer()
    }

    // MARK: - Trusted Peers

    private func loadTrustedPeers() {
        if let saved = UserDefaults.standard.stringArray(forKey: trustedPeersKey) {
            trustedPeers = Set(saved)
            print("[ConnectionManager] Loaded \(trustedPeers.count) trusted peers")
        }
    }

    private func saveTrustedPeers() {
        UserDefaults.standard.set(Array(trustedPeers), forKey: trustedPeersKey)
    }

    /// Lägg till en peer som betrodd
    func trustPeer(_ peerName: String) {
        trustedPeers.insert(peerName)
        saveTrustedPeers()
        print("[ConnectionManager] Added trusted peer: \(peerName)")
    }

    /// Ta bort en peer från betrodda
    func untrustPeer(_ peerName: String) {
        trustedPeers.remove(peerName)
        saveTrustedPeers()
        print("[ConnectionManager] Removed trusted peer: \(peerName)")
    }

    /// Acceptera väntande anslutning
    func acceptPendingInvitation(andTrust: Bool) {
        guard let invitation = pendingInvitation else { return }

        if andTrust {
            trustPeer(invitation.peerName)
        }

        invitation.handler(true)
        pendingInvitation = nil
        print("[ConnectionManager] Accepted invitation from: \(invitation.peerName)")
    }

    /// Avvisa väntande anslutning
    func rejectPendingInvitation() {
        guard let invitation = pendingInvitation else { return }

        invitation.handler(false)
        pendingInvitation = nil
        print("[ConnectionManager] Rejected invitation from: \(invitation.peerName)")
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
        stopAppListTimer()
    }

    // MARK: - App List

    /// Hämta körande presentationsappar
    func getRunningPresentationApps() -> [AppInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontmostApp = NSWorkspace.shared.frontmostApplication

        return runningApps.compactMap { app -> AppInfo? in
            guard let bundleId = app.bundleIdentifier,
                  presentationAppBundleIds.contains(bundleId),
                  let name = app.localizedName else {
                return nil
            }
            let isActive = app.bundleIdentifier == frontmostApp?.bundleIdentifier
            return AppInfo(id: bundleId, name: name, isActive: isActive)
        }
        .sorted { $0.name < $1.name }
    }

    /// Skicka app-lista till ansluten peer
    func sendAppList() {
        guard let peer = authorizedPeerID else { return }

        let apps = getRunningPresentationApps()
        let message = AppMessage.appList(apps)

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer], with: .reliable)
            print("[ConnectionManager] Sent app list: \(apps.map { $0.name })")
        } catch {
            print("[ConnectionManager] Failed to send app list: \(error)")
        }
    }

    private func startAppListTimer() {
        stopAppListTimer()

        // Skicka app-lista direkt vid anslutning
        sendAppList()

        // Sedan var 5:e sekund
        appListTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendAppList()
        }
    }

    private func stopAppListTimer() {
        appListTimer?.invalidate()
        appListTimer = nil
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
                self.startAppListTimer()
                print("[ConnectionManager] Connected to: \(peerID.displayName)")

            case .notConnected:
                if peerID == self.authorizedPeerID {
                    self.authorizedPeerID = nil
                    self.connectionState = .disconnected
                    self.connectedPeerName = nil
                    self.selectedAppBundleId = nil
                    self.stopAppListTimer()
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

        // Försök parsa som AppMessage först (nyaste format)
        if let message = try? JSONDecoder().decode(AppMessage.self, from: data) {
            handleAppMessage(message, from: peerID)
            return
        }

        // Försök parsa som JSON dictionary (äldre format)
        var commandString: String
        var source: String = "phone"
        var targetApp: String? = nil

        if let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let cmd = payload["command"] {
            commandString = cmd
            source = payload["source"] ?? "phone"
            targetApp = payload["targetApp"]
        } else if let plainCommand = String(data: data, encoding: .utf8) {
            // Fallback för äldsta format (ren text)
            commandString = plainCommand
        } else {
            print("[ConnectionManager] Invalid command data")
            return
        }

        processCommand(commandString, source: source, targetApp: targetApp, from: peerID)
    }

    private func handleAppMessage(_ message: AppMessage, from peerID: MCPeerID) {
        switch message {
        case .selectApp(let bundleId):
            DispatchQueue.main.async {
                self.selectedAppBundleId = bundleId
                print("[ConnectionManager] Selected target app: \(bundleId)")
            }

        case .command(let cmd, let source, let targetApp):
            processCommand(cmd, source: source, targetApp: targetApp, from: peerID)

        case .appList:
            // Mac skickar appList, tar inte emot
            print("[ConnectionManager] Received unexpected appList message")
        }
    }

    private func processCommand(_ commandString: String, source: String, targetApp: String?, from peerID: MCPeerID) {
        guard let command = PresentationCommand(rawValue: commandString) else {
            print("[ConnectionManager] Unknown command: \(commandString)")
            return
        }

        // Använd explicit targetApp, annars fall tillbaka på selectedAppBundleId
        let effectiveTargetApp = targetApp ?? selectedAppBundleId

        print("[ConnectionManager] Received: \(command.rawValue) from \(source), target: \(effectiveTargetApp ?? "any")")

        DispatchQueue.main.async {
            self.lastCommand = command.rawValue
            self.lastCommandSource = source
        }

        // Kör handleCommand asynkront för att undvika blockerande Thread.sleep
        Task {
            let success = await keyboardSimulator.handleCommand(command, targetAppBundleId: effectiveTargetApp)

            // Skicka ACK tillbaka
            let ack = CommandAck(command: command, success: success)
            if let ackData = try? JSONEncoder().encode(ack) {
                try? self.session.send(ackData, toPeers: [peerID], with: .reliable)
            }
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
        let peerName = peerID.displayName

        // Om peer redan är betrodd, acceptera direkt
        if trustedPeers.contains(peerName) {
            invitationHandler(true, session)
            print("[ConnectionManager] Auto-accepted trusted peer: \(peerName)")
            return
        }

        // Annars, spara förfrågan och vänta på användarens beslut
        DispatchQueue.main.async {
            // Avvisa eventuell tidigare väntande förfrågan
            self.pendingInvitation?.handler(false)

            self.pendingInvitation = PendingInvitation(peerName: peerName) { accepted in
                invitationHandler(accepted, accepted ? self.session : nil)
            }

            print("[ConnectionManager] Pending invitation from unknown peer: \(peerName)")

            // Visa notifikation till användaren
            self.showConnectionRequestNotification(from: peerName)
        }
    }

    private func showConnectionRequestNotification(from peerName: String) {
        let content = UNMutableNotificationContent()
        content.title = "FlickSlides"
        content.body = "\(peerName) vill ansluta"
        content.categoryIdentifier = "CONNECTION_REQUEST"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "connection-\(peerName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[ConnectionManager] Failed to show notification: \(error)")
            }
        }
    }

    /// Begär behörighet för notifikationer (anropas vid app-start)
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[ConnectionManager] Notification permission error: \(error)")
            } else {
                print("[ConnectionManager] Notification permission granted: \(granted)")
            }
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[ConnectionManager] Failed to start advertising: \(error)")
        DispatchQueue.main.async {
            self.connectionState = .error(error.localizedDescription)
        }
    }
}
