import AppKit
import Combine

/// Hanterar menyradsikon och meny.
final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var connectionManager: ConnectionManager
    private var cancellables = Set<AnyCancellable>()

    private var statusMenuItem: NSMenuItem!

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        setupStatusItem()
        setupMenu()
        observeConnectionState()
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

        // Senaste kommando
        let lastCommandItem = NSMenuItem(title: "Senaste: -", action: nil, keyEquivalent: "")
        lastCommandItem.isEnabled = false
        lastCommandItem.tag = 100
        menu.addItem(lastCommandItem)

        menu.addItem(NSMenuItem.separator())

        // Accessibility-status
        let accessibilityItem = NSMenuItem(
            title: AccessibilityManager.isAccessibilityEnabled ? "✓ Behörighet OK" : "⚠ Behörighet saknas",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

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

        connectionManager.$lastCommand
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                if let command,
                   let menuItem = self?.statusItem.menu?.item(withTag: 100) {
                    menuItem.title = "Senaste: \(command)"
                }
            }
            .store(in: &cancellables)
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityManager.openAccessibilitySettings()
    }
}
