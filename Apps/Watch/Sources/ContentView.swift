import SwiftUI
import WatchKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var presentationManager = PresentationManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusSection
                Spacer()
                mainButton
                Spacer()
                fallbackButtons
            }
            .padding()
            .navigationTitle("FlickSlides")
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(presentationManager.isPresentationMode ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(presentationManager.isPresentationMode ? "Aktivt" : "Inaktivt")
                    .font(.caption)
            }
            Text(presentationManager.connectionState)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let lastCommand = presentationManager.lastCommand {
                Text("Senaste: \(lastCommand)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
            VStack {
                Image(systemName: presentationManager.isPresentationMode
                    ? "stop.circle.fill"
                    : "play.circle.fill")
                    .font(.system(size: 44))
                Text(presentationManager.isPresentationMode ? "Stoppa" : "Starta")
                    .font(.headline)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(presentationManager.isPresentationMode ? .red : .green)
    }

    // MARK: - Fallback Buttons

    private var fallbackButtons: some View {
        HStack(spacing: 20) {
            Button {
                sendFallbackCommand("PREV")
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .buttonStyle(.bordered)

            Button {
                sendFallbackCommand("NEXT")
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
        }
        .disabled(!presentationManager.isPresentationMode)
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
