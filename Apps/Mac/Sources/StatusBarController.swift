import AppKit
import Combine

/// Hanterar menyradsikon och meny.
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var connectionManager: ConnectionManager
    private var cancellables = Set<AnyCancellable>()

    private var statusMenuItem: NSMenuItem!
    private var pendingInvitationItem: NSMenuItem!
    private var trustedPeersSubmenu: NSMenu!
    private var accessibilityMenuItem: NSMenuItem!

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        setupStatusItem()
        setupMenu()
        observeConnectionState()
        startAccessibilityStatusTimer()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(connected: false)
    }

    private func updateIcon(connected: Bool) {
        guard let button = statusItem.button else { return }

        let symbolName = connected ? "hand.point.right.fill" : "hand.point.right"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "FlickSlides") {
            image.isTemplate = true
            button.image = image
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status
        statusMenuItem = NSMenuItem(title: "Ej ansluten", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Väntande anslutningsförfrågan
        pendingInvitationItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        pendingInvitationItem.isHidden = true
        menu.addItem(pendingInvitationItem)

        // Senaste kommando
        let lastCommandItem = NSMenuItem(title: "Senaste: -", action: nil, keyEquivalent: "")
        lastCommandItem.isEnabled = false
        lastCommandItem.tag = 100
        menu.addItem(lastCommandItem)

        menu.addItem(NSMenuItem.separator())

        // Betrodda enheter
        let trustedPeersItem = NSMenuItem(title: "Betrodda enheter", action: nil, keyEquivalent: "")
        trustedPeersSubmenu = NSMenu()
        trustedPeersItem.submenu = trustedPeersSubmenu
        menu.addItem(trustedPeersItem)

        menu.addItem(NSMenuItem.separator())

        // Accessibility-status (uppdateras dynamiskt)
        accessibilityMenuItem = NSMenuItem(
            title: "",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityMenuItem.target = self
        updateAccessibilityStatus()
        menu.addItem(accessibilityMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Avsluta
        menu.addItem(NSMenuItem(title: "Avsluta FlickSlides",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func observeConnectionState() {
        connectionManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }

                switch state {
                case .connected(let deviceName):
                    self.updateIcon(connected: true)
                    self.statusMenuItem.title = "Ansluten: \(deviceName)"
                case .disconnected:
                    self.updateIcon(connected: false)
                    self.statusMenuItem.title = "Ej ansluten"
                case .searching:
                    self.updateIcon(connected: false)
                    self.statusMenuItem.title = "Söker..."
                case .connecting:
                    self.updateIcon(connected: false)
                    self.statusMenuItem.title = "Ansluter..."
                case .error(let msg):
                    self.updateIcon(connected: false)
                    self.statusMenuItem.title = "Fel: \(msg)"
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            connectionManager.$lastCommand,
            connectionManager.$lastCommandSource
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] command, source in
            guard let menuItem = self?.statusItem.menu?.item(withTag: 100) else { return }

            if let command {
                let sourceEmoji: String
                switch source {
                case "watch":
                    sourceEmoji = " (⌚)"
                case "phone":
                    sourceEmoji = " (📱)"
                default:
                    sourceEmoji = ""
                }
                menuItem.title = "Senaste: \(command)\(sourceEmoji)"
            }
        }
        .store(in: &cancellables)

        // Observera väntande anslutningsförfrågningar
        connectionManager.$pendingInvitation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] invitation in
                guard let self else { return }
                self.updatePendingInvitation(invitation)
            }
            .store(in: &cancellables)

        // Observera betrodda enheter
        connectionManager.$trustedPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in
                guard let self else { return }
                self.updateTrustedPeersSubmenu(peers)
            }
            .store(in: &cancellables)
    }

    private func updatePendingInvitation(_ invitation: ConnectionManager.PendingInvitation?) {
        if let invitation {
            pendingInvitationItem.isHidden = false

            let submenu = NSMenu()
            let acceptItem = NSMenuItem(title: "Tillåt \(invitation.peerName)", action: #selector(acceptInvitation), keyEquivalent: "")
            acceptItem.target = self
            submenu.addItem(acceptItem)

            let acceptAndTrustItem = NSMenuItem(title: "Tillåt och kom ihåg", action: #selector(acceptAndTrustInvitation), keyEquivalent: "")
            acceptAndTrustItem.target = self
            submenu.addItem(acceptAndTrustItem)

            let rejectItem = NSMenuItem(title: "Avvisa", action: #selector(rejectInvitation), keyEquivalent: "")
            rejectItem.target = self
            submenu.addItem(rejectItem)

            pendingInvitationItem.title = "⚠️ \(invitation.peerName) vill ansluta"
            pendingInvitationItem.submenu = submenu
        } else {
            pendingInvitationItem.isHidden = true
            pendingInvitationItem.submenu = nil
        }
    }

    private func updateTrustedPeersSubmenu(_ peers: Set<String>) {
        trustedPeersSubmenu.removeAllItems()

        if peers.isEmpty {
            let emptyItem = NSMenuItem(title: "Inga betrodda enheter", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            trustedPeersSubmenu.addItem(emptyItem)
        } else {
            for peer in peers.sorted() {
                let item = NSMenuItem(title: peer, action: nil, keyEquivalent: "")
                let removeItem = NSMenuItem(title: "Ta bort", action: #selector(removeTrustedPeer(_:)), keyEquivalent: "")
                removeItem.target = self
                removeItem.representedObject = peer

                let submenu = NSMenu()
                submenu.addItem(removeItem)
                item.submenu = submenu

                trustedPeersSubmenu.addItem(item)
            }
        }
    }

    @objc private func acceptInvitation() {
        connectionManager.acceptPendingInvitation(andTrust: false)
    }

    @objc private func acceptAndTrustInvitation() {
        connectionManager.acceptPendingInvitation(andTrust: true)
    }

    @objc private func rejectInvitation() {
        connectionManager.rejectPendingInvitation()
    }

    @objc private func removeTrustedPeer(_ sender: NSMenuItem) {
        guard let peerName = sender.representedObject as? String else { return }
        connectionManager.untrustPeer(peerName)
    }

    private func updateAccessibilityStatus() {
        let isEnabled = AccessibilityManager.isAccessibilityEnabled
        accessibilityMenuItem.title = isEnabled ? "✓ Behörighet OK" : "⚠ Behörighet saknas"
    }

    private func startAccessibilityStatusTimer() {
        // Kontrollera accessibility-status var 5:e sekund
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateAccessibilityStatus()
        }
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityManager.openAccessibilitySettings()
    }
}
