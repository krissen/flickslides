import SwiftUI
import WatchKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var presentationManager = PresentationManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // Status
            statusSection

            Spacer()

            // Huvudknapp
            mainButton

            Spacer()

            // Fallback-knappar
            fallbackButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 2) {
            Text("FlickSlides")
                .font(.headline)

            HStack(spacing: 4) {
                Circle()
                    .fill(presentationManager.isPresentationMode ? .green : .gray)
                    .frame(width: 6, height: 6)
                Text(presentationManager.isPresentationMode ? "Aktivt" : "Inaktivt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(presentationManager.connectionState)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Main Button

    private var mainButton: some View {
        Button {
            Task {
                if presentationManager.isPresentationMode {
                    await presentationManager.stopPresentation()
                } else {
                    await presentationManager.startPresentation()
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: presentationManager.isPresentationMode
                    ? "stop.fill"
                    : "play.fill")
                    .font(.system(size: 32))
                Text(presentationManager.isPresentationMode ? "Stoppa" : "Starta")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(presentationManager.isPresentationMode ? .red : .green)
    }

    // MARK: - Fallback Buttons

    private var fallbackButtons: some View {
        HStack(spacing: 16) {
            Button {
                sendFallbackCommand("PREV")
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.bordered)
            .disabled(!presentationManager.isPresentationMode)
            .opacity(presentationManager.isPresentationMode ? 1.0 : 0.4)

            Button {
                sendFallbackCommand("NEXT")
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.bordered)
            .disabled(!presentationManager.isPresentationMode)
            .opacity(presentationManager.isPresentationMode ? 1.0 : 0.4)
        }
    }

    private func sendFallbackCommand(_ command: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["command": command], replyHandler: nil)
        WKInterfaceDevice.current().play(.click)
    }
}

#Preview {
    ContentView()
}
