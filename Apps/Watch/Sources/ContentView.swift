import SwiftUI
import WatchKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var presentationManager = PresentationManager.shared
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 8) {
            // Status
            statusSection

            Spacer()

            // Huvudknapp
            mainButton

            Spacer()

            // Fallback-knappar
            fallbackButtons
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(presentationManager.isPresentationMode ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(presentationManager.isPresentationMode ? "Aktivt" : "Inaktivt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(presentationManager.connectionState)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Main Button

    private var mainButton: some View {
        Button {
            guard !isLoading else { return }
            isLoading = true
            WKInterfaceDevice.current().play(.click)

            Task {
                if presentationManager.isPresentationMode {
                    await presentationManager.stopPresentation()
                } else {
                    await presentationManager.startPresentation()
                }
                isLoading = false
            }
        } label: {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .frame(height: 36)
                } else {
                    Image(systemName: presentationManager.isPresentationMode
                        ? "stop.fill"
                        : "play.fill")
                        .font(.system(size: 36))
                }
                Text(buttonText)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(buttonTint)
        .disabled(isLoading)
    }

    private var buttonText: String {
        if isLoading {
            return presentationManager.isPresentationMode ? "Stoppar..." : "Startar..."
        }
        return presentationManager.isPresentationMode ? "Stoppa" : "Starta"
    }

    private var buttonTint: Color {
        if isLoading {
            return .orange
        }
        return presentationManager.isPresentationMode ? .red : .green
    }

    // MARK: - Fallback Buttons

    private var fallbackButtons: some View {
        HStack(spacing: 16) {
            Button {
                sendFallbackCommand("PREV")
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
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
                    .fontWeight(.semibold)
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
