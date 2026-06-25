import SwiftUI
import WatchKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var presentationManager = PresentationManager.shared
    @ObservedObject private var calibrationCoordinator = WatchCalibrationCoordinator.shared
    @State private var showCalibration = false
    @State private var navigateToCalibration = false

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: WatchCalibrationView()) {
                        Image(systemName: "gearshape")
                            .font(.caption)
                    }
                    .accessibilityLabel("Inställningar")
                    .accessibilityHint("Öppna kalibrering och inställningar")
                }
            }
            .navigationDestination(isPresented: $navigateToCalibration) {
                WatchCalibrationView()
            }
            .alert("Kalibrering", isPresented: $calibrationCoordinator.showCalibrationRequest) {
                Button("Starta") {
                    calibrationCoordinator.acceptCalibrationRequest()
                    navigateToCalibration = true
                }
                Button("Avbryt", role: .cancel) {
                    calibrationCoordinator.declineCalibrationRequest()
                }
            } message: {
                Text("iPhone vill starta gestkalibrering. Vill du fortsätta?")
            }
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusAccessibilityLabel)
    }

    private var statusAccessibilityLabel: String {
        let modeStatus = presentationManager.isPresentationMode ? "Presentationsläge aktivt" : "Presentationsläge inaktivt"
        return "\(modeStatus). \(presentationManager.connectionState)"
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
                if presentationManager.isTransitioning {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 32)
                } else {
                    Image(systemName: presentationManager.isPresentationMode
                        ? "stop.fill"
                        : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                Text(buttonText)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonTint)
            )
        }
        .buttonStyle(.plain)
        .disabled(presentationManager.isTransitioning)
        .accessibilityLabel(mainButtonAccessibilityLabel)
        .accessibilityHint(mainButtonAccessibilityHint)
    }

    private var mainButtonAccessibilityLabel: String {
        if presentationManager.isTransitioning {
            return presentationManager.isPresentationMode ? "Stoppar presentation" : "Startar presentation"
        }
        return presentationManager.isPresentationMode ? "Stoppa presentation" : "Starta presentation"
    }

    private var mainButtonAccessibilityHint: String {
        if presentationManager.isTransitioning {
            return "Vänta medan läget ändras"
        }
        return presentationManager.isPresentationMode
            ? "Dubbelklicka för att avsluta presentationsläge"
            : "Dubbelklicka för att aktivera gestdetektering"
    }

    private var buttonText: String {
        if presentationManager.isTransitioning {
            return presentationManager.isPresentationMode ? "Stoppar..." : "Startar..."
        }
        return presentationManager.isPresentationMode ? "Stoppa" : "Starta"
    }

    private var buttonTint: Color {
        if presentationManager.isTransitioning {
            return .orange
        }
        return presentationManager.isPresentationMode ? .red : .green
    }

    // MARK: - Fallback Buttons
    // Knapparna fungerar alltid (även utan gestdetektering) så länge det finns anslutning

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
            .accessibilityLabel("Föregående slide")
            .accessibilityHint("Dubbelklicka för att gå till föregående slide")

            Button {
                sendFallbackCommand("NEXT")
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Nästa slide")
            .accessibilityHint("Dubbelklicka för att gå till nästa slide")
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
