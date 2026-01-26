import SwiftUI
import FlickSlidesKit

/// Kalibreringsvy för Phone - orkestrerar inspelning på Watch.
struct PhoneCalibrationView: View {
    @StateObject private var manager = PhoneCalibrationManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch manager.phase {
                case .idle:
                    idleView
                case .intro:
                    introView
                case .collectingForward(let collected, let target):
                    collectingView(
                        title: "Nästa-gest",
                        instruction: manager.currentPrompt,
                        collected: collected,
                        target: target,
                        color: .blue
                    )
                case .collectingBackward(let collected, let target):
                    collectingView(
                        title: "Föregående-gest",
                        instruction: manager.currentPrompt,
                        collected: collected,
                        target: target,
                        color: .purple
                    )
                case .collectingNegative(let collected, let target):
                    collectingView(
                        title: "Negativa exempel",
                        instruction: manager.currentPrompt,
                        collected: collected,
                        target: target,
                        color: .orange
                    )
                case .analyzing:
                    analyzingView
                case .needsMoreSamples(let reason):
                    needsMoreView(reason: reason)
                case .complete(let stats):
                    completeView(stats: stats)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding()
            .navigationTitle("Kalibrering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        manager.abortCalibration()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Lär appen dina gester")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Kalibrering anpassar gestdetekteringen efter hur just du gör dina blädvändrörelser.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                watchStatusView

                Button {
                    Task {
                        await manager.startCalibration()
                    }
                } label: {
                    Label("Starta kalibrering", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!manager.isWatchReady && manager.phase == .idle)
            }
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Väntar på Watch...")
                .font(.headline)

            Text("Öppna FlickSlides på din Apple Watch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Collecting View

    private func collectingView(
        title: String,
        instruction: String,
        collected: Int,
        target: Int,
        color: Color
    ) -> some View {
        VStack(spacing: 24) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: CGFloat(collected) / CGFloat(max(target, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: collected)

                VStack(spacing: 4) {
                    Text("\(collected)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("av \(target)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.top, 40)

            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            // Instruction
            Text(instruction)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(minHeight: 60)

            // Status indicator
            if manager.isWaitingForIdle {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.yellow)
                    Text("Håll armen still...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(8)
            } else if manager.isReadyForGesture {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Gör gesten NU!")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
            }

            Spacer()

            // Watch status
            HStack {
                Circle()
                    .fill(manager.isWatchReady ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(manager.isWatchReady ? "Watch ansluten" : "Watch frånkopplad")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Analyserar...")
                .font(.headline)

            Text("Bearbetar insamlade gester och tar bort avvikelser")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Needs More View

    private func needsMoreView(reason: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Behöver fler gester")
                .font(.title2)
                .fontWeight(.semibold)

            Text(reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Complete View

    private func completeView(stats: CalibrationStats) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Kalibrering klar!")
                .font(.title)
                .fontWeight(.bold)

            // Stats
            VStack(alignment: .leading, spacing: 12) {
                statsRow(label: "Nästa-gester", count: stats.forwardKept, color: .blue)
                statsRow(label: "Föregående-gester", count: stats.backwardKept, color: .purple)
                statsRow(label: "Negativa exempel", count: stats.negativeKept, color: .orange)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Klar")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }

    private func statsRow(label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
            Spacer()
            Text("\(count) st")
                .fontWeight(.semibold)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Något gick fel")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await manager.startCalibration()
                }
            } label: {
                Label("Försök igen", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Watch Status

    private var watchStatusView: some View {
        HStack {
            Image(systemName: manager.isWatchReady ? "applewatch" : "applewatch.slash")
                .foregroundColor(manager.isWatchReady ? .green : .gray)
            Text(manager.isWatchReady ? "Watch redo" : "Väntar på Watch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PhoneCalibrationView()
}
