# macOS Tangentbordssimulering och Menyradsapp

## Sammanfattning

FlickSlides Mac-app kräver:
- **Accessibility-behörighet** för tangentbordssimulering (obligatorisk)
- **Local Network Access** för MultipeerConnectivity (automatisk prompt)
- **Distribution utanför App Store** (sandbox blockerar CGEvent)

**Rekommendation:** Notariserad distribution via Developer ID, inte App Store.

---

## 1. CGEvent/Quartz Event Services

### Virtual Keycodes

| Tangent | Keycode | Beskrivning |
|---------|---------|-------------|
| Höger pil (→) | 124 | Nästa slide |
| Vänster pil (←) | 123 | Föregående slide |
| B | 11 | Blackout |
| Escape | 53 | Avsluta presentation |

### Komplett KeyboardSimulator

```swift
import CoreGraphics

final class KeyboardSimulator {
    static let VK_RIGHT_ARROW: CGKeyCode = 124
    static let VK_LEFT_ARROW: CGKeyCode = 123
    static let VK_B: CGKeyCode = 11
    static let VK_ESCAPE: CGKeyCode = 53

    private var lastCommandTime: Date = .distantPast
    private let debounceInterval: TimeInterval

    init(debounceInterval: TimeInterval = 0.5) {
        self.debounceInterval = debounceInterval
    }

    @discardableResult
    func sendKey(_ keyCode: CGKeyCode) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTime) > debounceInterval else {
            return false
        }
        lastCommandTime = now

        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source,
                                     virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source,
                                   virtualKey: keyCode, keyDown: false) else {
            return false
        }

        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }

    func handleCommand(_ command: PresentationCommand) -> Bool {
        return sendKey(CGKeyCode(command.keyCode))
    }
}
```

**Viktigt:** `.cgSessionEventTap` postar events till användarens session. `.combinedSessionState` respekterar modifier-tangenter.

---

## 2. Accessibility-behörigheter

### AccessibilityManager

```swift
import ApplicationServices
import AppKit

final class AccessibilityManager {
    static var isAccessibilityEnabled: Bool {
        return AXIsProcessTrusted()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func showPermissionExplanation(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Behörighet krävs"
        alert.informativeText = """
            FlickSlides behöver behörighet som Hjälpmedel för att kunna \
            skicka tangentbordskommandon till presentationsappen.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Fortsätt")
        alert.addButton(withTitle: "Avbryt")

        if alert.runModal() == .alertFirstButtonReturn {
            completion(requestPermission())
        } else {
            completion(false)
        }
    }
}
```

### Behörighetsflöde steg-för-steg

**Vid första start:**

1. **App startar** → Kontrollerar `AXIsProcessTrusted()`
2. **Om false** → Visar egen förklaringsdialog
3. **Användaren klickar "Fortsätt"** → `AXIsProcessTrustedWithOptions(prompt: true)` anropas
4. **Systeminställningar öppnas** → Hjälpmedel-panelen
5. **Användaren aktiverar FlickSlides** → Kan kräva Touch ID/lösenord
6. **Appen börjar fungera** → Tangentbordssimulering aktiverad

---

## 3. NSStatusItem (Menyradsapp)

### StatusBarController

```swift
import AppKit
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var connectionManager: ConnectionManager
    private var cancellables = Set<AnyCancellable>()

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
        menu.addItem(NSMenuItem(title: "Ej ansluten", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Avsluta FlickSlides",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func observeConnectionState() {
        connectionManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .connected = state {
                    self?.updateIcon(connected: true)
                } else {
                    self?.updateIcon(connected: false)
                }
            }
            .store(in: &cancellables)
    }
}
```

**Info.plist för menyradsapp utan Dock-ikon:**
```xml
<key>LSUIElement</key>
<true/>
```

---

## 4. MultipeerConnectivity på macOS

### ConnectionManager (Advertiser)

```swift
import MultipeerConnectivity
import Combine

final class ConnectionManager: NSObject, ObservableObject {
    private let serviceType = "flickslides-ctrl"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private let keyboardSimulator: KeyboardSimulator

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var connectedPeerName: String?
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
    }

    func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
    }
}

extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.authorizedPeerID = peerID
                self.connectionState = .connected(deviceName: peerID.displayName)
            case .notConnected:
                if peerID == self.authorizedPeerID {
                    self.authorizedPeerID = nil
                    self.connectionState = .disconnected
                }
            default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard peerID == authorizedPeerID,
              let commandString = String(data: data, encoding: .utf8),
              let command = PresentationCommand(rawValue: commandString) else { return }

        let success = keyboardSimulator.handleCommand(command)

        // Skicka ACK tillbaka
        let ack = CommandAck(command: command, success: success)
        if let ackData = try? JSONEncoder().encode(ack) {
            try? session.send(ackData, toPeers: [peerID], with: .reliable)
        }
    }

    // Övriga delegate-metoder (stream, resource) - tomma implementationer
    func session(_ session: MCSession, didReceive stream: InputStream, withName: String, fromPeer: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                   withContext: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error)")
    }
}
```

**Info.plist för nätverk:**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>FlickSlides använder det lokala nätverket för att ta emot kommandon från din iPhone.</string>

<key>NSBonjourServices</key>
<array>
    <string>_flickslides-ctrl._tcp</string>
</array>
```

---

## 5. Sandbox-begränsningar

### Jämförelse: App Store vs Developer ID

| Kapabilitet | App Store (Sandbox) | Developer ID |
|-------------|--------------------|--------------|
| CGEvent tangentbordssimulering | **NEJ** | JA |
| Accessibility API | **NEJ** | JA |
| MultipeerConnectivity | JA | JA |

**Slutsats:** FlickSlides Mac-app **kan inte** distribueras via App Store p.g.a. sandbox-begränsningar för `CGEventPost()`.

### Entitlements för notariserad app

Fil: `FlickSlidesMac.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

---

## 6. Komplett AppDelegate

```swift
import AppKit
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private let connectionManager = ConnectionManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Kontrollera Accessibility-behörighet
        if !AccessibilityManager.isAccessibilityEnabled {
            AccessibilityManager.showPermissionExplanation { granted in
                if !granted {
                    // Visa instruktioner men fortsätt ändå
                    print("Accessibility permission not granted")
                }
            }
        }

        // 2. Skapa menyradsikon
        statusBarController = StatusBarController(connectionManager: connectionManager)

        // 3. Börja annonsera för iOS-anslutningar
        connectionManager.startAdvertising()
    }

    func applicationWillTerminate(_ notification: Notification) {
        connectionManager.stopAdvertising()
    }
}
```

---

## Risker och åtgärder

| Risk | Sannolikhet | Konsekvens | Åtgärd |
|------|-------------|------------|--------|
| App Store-distribution omöjlig | 100% | Medel | Planera för Developer ID från start |
| Accessibility-prompt förvirrande | Medel | Låg | Egen förklaringsdialog före systemprompt |
| macOS-uppdatering nollställer behörighet | Låg | Medel | Detektera vid start och guida användaren |
| Fullskärmsläge blockerar events | Låg | Hög | Testa noggrant med Keynote/PowerPoint |

---

## Nästa steg

1. Skapa macOS-app-projekt i Xcode
2. Integrera FlickSlidesKit som dependency
3. Implementera prototypkoden ovan
4. Testa med iOS-sändare (Browser-sidan)
5. Testa tangentbordssimulering mot Keynote, PowerPoint, PDF Preview
6. Konfigurera notariseringsflöde med Developer ID

---

*Rapport skapad: 2025-01-25*
*Status: KLAR*
