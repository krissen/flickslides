import SwiftUI

@main
struct FlickSlidesPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Förhindra skärmsläckning under presentation
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
