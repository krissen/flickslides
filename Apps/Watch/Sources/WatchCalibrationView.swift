import SwiftUI
import WatchKit
import FlickSlidesKit

/// Enkel kalibreringsvy för Watch - visar status och styrs från Phone.
struct WatchCalibrationView: View {
    @StateObject private var coordinator = WatchCalibrationCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            if coordinator.isCalibrationComplete {
                completeView
            } else if coordinator.isRecording {
                recordingView
            } else if coordinator.isReadyForGesture {
                readyForGestureView
            } else if coordinator.isWaitingForIdle {
                waitingForIdleView
            } else if coordinator.isCalibrationActive {
                waitingView
            } else {
                readyView
            }
        }
        .padding()
        .onAppear {
            coordinator.notifyWatchReady()
        }
        .onDisappear {
            coordinator.notifyWatchDismissed()
        }
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("Kalibrering klar!")
                .font(.headline)

            Button("Stäng") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    // MARK: - Ready View

    private var readyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            Text("Väntar på iPhone")
                .font(.headline)

            Text("Starta kalibrering från telefonen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Avbryt") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    // MARK: - Waiting For Idle View

    private var waitingForIdleView: some View {
        VStack(spacing: 12) {
            gestureTypeIndicator

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)

            Text("Håll armen still")
                .font(.headline)

            Text("Slappna av och vänta")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Ready For Gesture View

    private var readyForGestureView: some View {
        VStack(spacing: 12) {
            gestureTypeIndicator

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("Gör gesten NU!")
                .font(.headline)
                .foregroundStyle(.green)
        }
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        VStack(spacing: 12) {
            gestureTypeIndicator

            Text("Väntar...")
                .font(.headline)

            Text("Väntar på instruktion")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 12) {
            gestureTypeIndicator

            // Pulsing recording indicator
            ZStack {
                Circle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 60, height: 60)

                Circle()
                    .fill(.red)
                    .frame(width: 36, height: 36)
            }
            .modifier(PulseAnimation())

            Text("Spelar in...")
                .font(.headline)

            Text("#\(coordinator.currentSampleIndex + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Gesture Type Indicator

    @ViewBuilder
    private var gestureTypeIndicator: some View {
        if let gestureType = coordinator.currentGestureType {
            HStack(spacing: 6) {
                Image(systemName: gestureIcon(for: gestureType))
                    .foregroundStyle(gestureColor(for: gestureType))
                Text(gestureLabel(for: gestureType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(gestureColor(for: gestureType).opacity(0.15))
            .cornerRadius(8)
        }
    }

    private func gestureIcon(for type: GestureLabel) -> String {
        switch type {
        case .flickForward:
            return "arrow.right"
        case .flickBackward:
            return "arrow.left"
        case .negative:
            return "hand.raised"
        }
    }

    private func gestureLabel(for type: GestureLabel) -> String {
        switch type {
        case .flickForward:
            return "Nästa"
        case .flickBackward:
            return "Föregående"
        case .negative:
            return "Negativ"
        }
    }

    private func gestureColor(for type: GestureLabel) -> Color {
        switch type {
        case .flickForward:
            return .blue
        case .flickBackward:
            return .purple
        case .negative:
            return .orange
        }
    }
}

// MARK: - Pulse Animation

private struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    WatchCalibrationView()
}
