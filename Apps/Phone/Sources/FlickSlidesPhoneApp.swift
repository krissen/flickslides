import SwiftUI

@main
struct FlickSlidesPhoneApp: App {
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Förhindra skärmsläckning under presentation
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
        }
    }
}
