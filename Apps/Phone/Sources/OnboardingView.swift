import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "hand.wave.fill",
            title: "Välkommen till FlickSlides",
            description: "Styr dina presentationer med gester på Apple Watch. En snabb handrörelse byter slide."
        ),
        OnboardingPage(
            systemImage: "arrow.left.arrow.right",
            title: "Enkla gester",
            description: "Flicka handleden framåt för nästa slide, bakåt för föregående. Snabbt och naturligt."
        ),
        OnboardingPage(
            systemImage: "link",
            title: "Anslut din Mac",
            description: "iPhone fungerar som brygga mellan Watch och Mac. Anslut till din Mac när den visas i listan."
        ),
        OnboardingPage(
            systemImage: "gearshape.fill",
            title: "Kalibrera för bästa resultat",
            description: "Lär appen dina personliga gester via kalibrering. Du hittar den under Gestkalibrering."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 24)

            // Buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Tillbaka") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Nästa") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Kom igång") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.description)")
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        isPresented = false
    }
}

private struct OnboardingPage {
    let systemImage: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
