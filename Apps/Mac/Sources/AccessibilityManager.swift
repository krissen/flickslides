import ApplicationServices
import AppKit

/// Hanterar Accessibility-behörigheter.
enum AccessibilityManager {

    /// Kontrollera om appen har Accessibility-behörighet.
    static var isAccessibilityEnabled: Bool {
        return AXIsProcessTrusted()
    }

    /// Begär behörighet (visar systemprompt).
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Öppna Systeminställningar direkt till Accessibility-panelen.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Visa förklaringsdialog och begär behörighet.
    static func showPermissionExplanation(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Behörighet krävs"
        alert.informativeText = """
            FlickSlides behöver behörighet som Hjälpmedel för att kunna \
            skicka tangentbordskommandon till presentationsappen.

            1. Klicka "Fortsätt"
            2. Öppna Systeminställningar
            3. Aktivera FlickSlides i listan
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
