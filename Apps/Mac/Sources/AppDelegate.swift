import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private let connectionManager = ConnectionManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Kontrollera Accessibility-behörighet
        if !AccessibilityManager.isAccessibilityEnabled {
            AccessibilityManager.showPermissionExplanation { granted in
                if !granted {
                    print("[AppDelegate] Accessibility permission not granted")
                }
            }
        }

        // 2. Skapa menyradsikon
        statusBarController = StatusBarController(connectionManager: connectionManager)

        // 3. Börja annonsera för iOS-anslutningar
        connectionManager.startAdvertising()

        print("[AppDelegate] Application launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        connectionManager.stopAdvertising()
        print("[AppDelegate] Application terminating")
    }
}
