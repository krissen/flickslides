import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Status") {
                HStack {
                    Text("Accessibility-behörighet")
                    Spacer()
                    if AccessibilityManager.isAccessibilityEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("OK")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Button("Aktivera") {
                            AccessibilityManager.openAccessibilitySettings()
                        }
                    }
                }
            }

            Section("Om") {
                Text("FlickSlides för Mac")
                Text("Version 1.0.0")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 350, height: 200)
    }
}

#Preview {
    SettingsView()
}
