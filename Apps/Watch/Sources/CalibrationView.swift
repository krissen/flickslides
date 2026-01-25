import SwiftUI
import CoreMotion
import WatchKit

/// Kalibreringsvy för personaliserad gestinlärning.
///
/// Guider användaren genom att spela in ett antal gester för
/// "nästa", "föregående" samt negativa exempel (icke-gester).
struct CalibrationView: View {
    @StateObject private var viewModel = CalibrationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.phase {
            case .intro:
                introView
            case .collectingForward:
                collectingView(label: "Nasta", count: viewModel.forwardCount, target: viewModel.targetCount)
            case .collectingBackward:
                collectingView(label: "Foregaende", count: viewModel.backwardCount, target: viewModel.targetCount)
            case .collectingNegative:
                negativeView
            case .complete:
                completeView
            }
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: 12) {
            Text("Kalibrering")
                .font(.headline)

            Text("Lar appen dina gester for battre precision.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Starta") {
                viewModel.startCalibration()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
    }

    // MARK: - Collecting View

    private func collectingView(label: String, count: Int, target: Int) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.headline)

            Text("\(count) / \(target)")
                .font(.title2)
                .monospacedDigit()

            ProgressView(value: Double(count), total: Double(target))
                .tint(.green)

            Text("Gor '\(label)'-gesten")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.isRecording {
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
            }
        }
        .padding()
    }

    // MARK: - Negative View

    private var negativeView: some View {
        VStack(spacing: 8) {
            Text("Negativa")
                .font(.headline)

            Text("\(viewModel.negativeCount) / \(viewModel.negativeTarget)")
                .font(.title2)
                .monospacedDigit()

            ProgressView(value: Double(viewModel.negativeCount), total: Double(viewModel.negativeTarget))
                .tint(.orange)

            Text(viewModel.negativePrompt)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("Kalibrering klar!")
                .font(.headline)

            Text("\(viewModel.totalTemplates) gester sparade")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Klar") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - CalibrationViewModel

@MainActor
final class CalibrationViewModel: ObservableObject {

    // MARK: - Phase

    enum Phase {
        case intro
        case collectingForward
        case collectingBackward
        case collectingNegative
        case complete
    }

    // MARK: - Published State

    @Published var phase: Phase = .intro
    @Published var forwardCount = 0
    @Published var backwardCount = 0
    @Published var negativeCount = 0
    @Published var isRecording = false
    @Published var negativePrompt = "Ror dig naturligt"

    // MARK: - Configuration

    let targetCount = 12
    let negativeTarget = 20

    var totalTemplates: Int {
        forwardCount + backwardCount + negativeCount
    }

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private let store = GestureTemplateStore()
    private var templates: [DTWMatcher.GestureTemplate] = []
    private var currentSamples: [DTWMatcher.MotionSample] = []
    private var gestureStartTime: Date?
    private var currentLabel: DTWMatcher.GestureLabel = .flickForward

    private let negativePrompts = [
        "Lyft armen",
        "Sank armen",
        "Vifta handen",
        "Titta pa klockan",
        "Korsa armarna",
        "Gestikulera",
        "Skaka handen",
        "Peka framat",
        "Klappa handerna",
        "Justera klockan"
    ]
    private var promptIndex = 0

    // MARK: - Calibration Flow

    func startCalibration() {
        templates.removeAll()
        forwardCount = 0
        backwardCount = 0
        negativeCount = 0
        phase = .collectingForward
        currentLabel = .flickForward
        startMotionUpdates()
    }

    // MARK: - Motion Updates

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[CalibrationViewModel] Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            Task { @MainActor in
                self.processMotion(motion)
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func processMotion(_ motion: CMDeviceMotion) {
        let acc = motion.userAcceleration
        let rot = motion.rotationRate
        let accMagnitude = sqrt(acc.x*acc.x + acc.y*acc.y + acc.z*acc.z)

        // Detektera geststart
        if !isRecording && accMagnitude > 1.0 {
            isRecording = true
            gestureStartTime = Date()
            currentSamples.removeAll()
            WKInterfaceDevice.current().play(.start)
        }

        // Samla samples under gest
        if isRecording, let startTime = gestureStartTime {
            let sample = DTWMatcher.MotionSample(
                timestamp: Date().timeIntervalSince(startTime),
                accX: acc.x,
                accY: acc.y,
                accZ: acc.z,
                rotX: rot.x * 180.0 / .pi,
                rotY: rot.y * 180.0 / .pi,
                rotZ: rot.z * 180.0 / .pi
            )
            currentSamples.append(sample)

            // Avsluta efter 600ms eller när acceleration sjunker
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0.6 || (elapsed > 0.1 && accMagnitude < 0.3) {
                finishGesture()
            }
        }
    }

    // MARK: - Gesture Completion

    private func finishGesture() {
        guard currentSamples.count >= 5 else {
            isRecording = false
            return
        }

        let template = DTWMatcher.GestureTemplate(
            label: currentLabel,
            samples: currentSamples
        )
        templates.append(template)

        isRecording = false
        WKInterfaceDevice.current().play(.success)

        // Uppdatera raknare och fas
        switch currentLabel {
        case .flickForward:
            forwardCount += 1
            if forwardCount >= targetCount {
                phase = .collectingBackward
                currentLabel = .flickBackward
            }
        case .flickBackward:
            backwardCount += 1
            if backwardCount >= targetCount {
                phase = .collectingNegative
                currentLabel = .negative
                updateNegativePrompt()
            }
        case .negative:
            negativeCount += 1
            updateNegativePrompt()
            if negativeCount >= negativeTarget {
                finishCalibration()
            }
        }
    }

    private func updateNegativePrompt() {
        promptIndex = (promptIndex + 1) % negativePrompts.count
        negativePrompt = negativePrompts[promptIndex]
    }

    private func finishCalibration() {
        stopMotionUpdates()
        store.save(templates)
        phase = .complete
        WKInterfaceDevice.current().play(.success)
    }
}

// MARK: - Preview

#Preview {
    CalibrationView()
}
