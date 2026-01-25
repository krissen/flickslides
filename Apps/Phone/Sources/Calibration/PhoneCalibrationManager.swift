import Foundation
import FlickSlidesKit

/// Orkestrerar kalibrering av gester från Phone-sidan.
///
/// Implementerar adaptiv insamling:
/// 1. Samla 5 samples
/// 2. Analysera varians
/// 3. Om konsekvent → klar
/// 4. Om inte → be om fler samples, ta bort outliers
/// 5. Fortsätt tills vi har en bra uppsättning
@MainActor
final class PhoneCalibrationManager: ObservableObject {

    // MARK: - Configuration

    private enum Config {
        static let initialBatchSize = 5          // Första batchen
        static let additionalBatchSize = 5       // Extra samples vid behov
        static let minSamplesRequired = 5        // Minimum för att godkänna
        static let maxSamplesPerType = 15        // Max totalt per gest-typ
        static let samplesPerNegativeType = 5    // 5 samples per negativ gesttyp
        static let negativeSamplesTarget = 50    // 10 typer × 5 samples = 50 totalt
        static let recordingTimeoutSeconds = 10.0
    }

    // MARK: - Published State

    @Published private(set) var phase: CalibrationPhase = .idle
    @Published private(set) var isWatchReady = false
    @Published private(set) var currentPrompt: String = ""
    @Published private(set) var progress: Double = 0
    @Published private(set) var isWaitingForIdle = false
    @Published private(set) var isReadyForGesture = false
    @Published private(set) var isRecording = false

    // Continuation för att vänta på användaren
    private var userReadyContinuation: CheckedContinuation<Void, Never>?
    private var readyForGestureContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Dependencies

    private let watchSession = WatchSessionManager.shared
    private let outlierDetector = OutlierDetector(
        outlierThreshold: 1.5,
        minSamplesToKeep: 5,
        maxSamplesToKeep: 12
    )
    private let templateStore = GestureTemplateStore()

    // MARK: - Private State

    private var forwardSamples: [MotionSampleBatch] = []
    private var backwardSamples: [MotionSampleBatch] = []
    private var negativeSamples: [MotionSampleBatch] = []

    private var currentRecordingContinuation: CheckedContinuation<MotionSampleBatch?, Never>?
    private var isRecordingInProgress = false

    // Negative prompts - tydliga och specifika
    private let negativePrompts = [
        "LYFT armen rakt upp och ner igen",
        "VRID handleden fram och tillbaka",
        "PEKA framat med fingret",
        "TITTA pa klockan (lyft armen till ansiktet)",
        "VIFTA handen fram och tillbaka",
        "SKAKA handen latt",
        "GOR en cirkelrorelse med handen",
        "LYFT handen till axeln",
        "LATSAS klappa nagon pa axeln",
        "STRYK dig over pannan"
    ]

    // MARK: - Initialization

    init() {
        setupMessageHandling()
    }

    private func setupMessageHandling() {
        watchSession.onCalibrationMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleWatchMessage(message)
            }
        }
    }

    // MARK: - Public API

    /// Startar kalibreringsflödet.
    func startCalibration() async {
        guard case .idle = phase else { return }

        // Rensa tidigare data
        forwardSamples.removeAll()
        backwardSamples.removeAll()
        negativeSamples.removeAll()

        phase = .intro
        progress = 0

        // Vänta på att Watch är redo
        await waitForWatch()

        guard isWatchReady else {
            phase = .error(message: "Watch ej tillganglig")
            return
        }

        // Samla Forward-gester
        await collectGestureType(.flickForward, prompt: "Gor en NASTA-gest (flikca framat)")

        // Samla Backward-gester
        await collectGestureType(.flickBackward, prompt: "Gor en FOREGAENDE-gest (flikca bakat)")

        // Samla Negativa samples
        await collectNegativeSamples()

        // Analysera och spara
        await analyzeAndSave()
    }

    /// Avbryter kalibrering.
    func abortCalibration() {
        watchSession.sendCalibrationMessage(.calibrationAborted)
        resumeRecordingContinuation(with: nil)
        readyForGestureContinuation?.resume()
        readyForGestureContinuation = nil
        phase = .idle
        isWatchReady = false
        isWaitingForIdle = false
        isReadyForGesture = false
        isRecordingInProgress = false
    }

    // MARK: - Watch Communication

    private func waitForWatch() async {
        // Pinga Watch
        watchSession.sendCalibrationMessage(.ping)

        // Vänta på svar (max 5 sekunder)
        for _ in 0..<50 {
            if isWatchReady { return }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    private func handleWatchMessage(_ message: CalibrationMessage) {
        switch message {
        case .pong, .watchReady:
            isWatchReady = true

        case .watchDismissed:
            isWatchReady = false
            if case .idle = phase {} else {
                phase = .error(message: "Watch avslutade kalibrering")
            }

        case .recordingStarted:
            isRecordingInProgress = true
            isWaitingForIdle = true
            isReadyForGesture = false

        case .readyForGesture:
            isWaitingForIdle = false
            isReadyForGesture = true
            readyForGestureContinuation?.resume()
            readyForGestureContinuation = nil

        case .sampleRecorded(let batch):
            isRecordingInProgress = false
            isWaitingForIdle = false
            isReadyForGesture = false
            resumeRecordingContinuation(with: batch)

        case .recordingFailed(let reason):
            isRecordingInProgress = false
            isWaitingForIdle = false
            isReadyForGesture = false
            print("[PhoneCalibrationManager] Recording failed: \(reason)")
            // Vi försöker igen automatiskt

        // Meddelanden som Phone skickar
        case .startRecording, .stopRecording, .calibrationAborted, .ping:
            break
        }
    }

    private func resumeRecordingContinuation(with batch: MotionSampleBatch?) {
        currentRecordingContinuation?.resume(returning: batch)
        currentRecordingContinuation = nil
    }

    // MARK: - Adaptive Collection

    private func collectGestureType(_ gestureType: GestureLabel, prompt: String) async {
        let samples = gestureType == .flickForward ? forwardSamples : backwardSamples

        var collected = samples
        var batchNumber = 1

        while collected.count < Config.maxSamplesPerType {
            let needed = min(Config.initialBatchSize, Config.maxSamplesPerType - collected.count)

            // Uppdatera UI
            updatePhase(for: gestureType, collected: collected.count, collecting: needed)
            currentPrompt = prompt

            // Samla batch
            let newSamples = await collectBatch(
                gestureType: gestureType,
                count: needed,
                startIndex: collected.count
            )
            collected.append(contentsOf: newSamples)

            // Analysera
            let analysis = outlierDetector.analyze(collected)

            if analysis.kept.count >= Config.minSamplesRequired && !analysis.varianceIsHigh {
                // Bra konsistens - vi är klara
                collected = analysis.kept
                print("[PhoneCalibrationManager] \(gestureType): Good consistency after batch \(batchNumber), keeping \(collected.count) samples")
                break
            }

            if collected.count >= Config.maxSamplesPerType {
                // Max nått - ta de bästa vi har
                collected = analysis.kept
                print("[PhoneCalibrationManager] \(gestureType): Max reached, keeping \(collected.count) samples")
                break
            }

            // Behöver fler samples
            print("[PhoneCalibrationManager] \(gestureType): Variance high, requesting more samples (batch \(batchNumber + 1))")
            collected = analysis.kept // Behåll bara de bra
            batchNumber += 1
        }

        // Spara resultatet
        if gestureType == .flickForward {
            forwardSamples = collected
        } else {
            backwardSamples = collected
        }
    }

    private func collectNegativeSamples() async {
        var collected: [MotionSampleBatch] = []
        var promptIndex = 0
        var samplesPerPrompt = [String: Int]()  // Spåra hur många samples per prompt-typ

        // Initiera räknarna
        for prompt in negativePrompts {
            samplesPerPrompt[prompt] = 0
        }

        while collected.count < Config.negativeSamplesTarget {
            // Hitta nästa prompt som behöver fler samples (rotation)
            var currentPrompt: String?
            var attempts = 0

            repeat {
                currentPrompt = negativePrompts[promptIndex % negativePrompts.count]
                promptIndex += 1
                attempts += 1
            } while (samplesPerPrompt[currentPrompt!] ?? 0) >= Config.samplesPerNegativeType && attempts < negativePrompts.count

            guard let prompt = currentPrompt, (samplesPerPrompt[prompt] ?? 0) < Config.samplesPerNegativeType else {
                break  // Alla prompts har nått sitt mål
            }

            self.currentPrompt = prompt

            phase = .collectingNegative(
                collected: collected.count,
                target: Config.negativeSamplesTarget
            )

            if let batch = await recordSingleSample(
                gestureType: .negative,
                index: collected.count
            ) {
                collected.append(batch)
                samplesPerPrompt[prompt, default: 0] += 1
            }
        }

        // Analysera negativa (mindre strikt)
        let analysis = outlierDetector.analyze(collected)
        negativeSamples = analysis.kept

        // Skriv ut statistik per prompt-typ
        print("[PhoneCalibrationManager] Negative samples per type:")
        for prompt in negativePrompts {
            print("  - \(prompt): \(samplesPerPrompt[prompt] ?? 0) samples")
        }
        print("[PhoneCalibrationManager] Negative: keeping \(negativeSamples.count) of \(collected.count) samples")
    }

    private func collectBatch(
        gestureType: GestureLabel,
        count: Int,
        startIndex: Int
    ) async -> [MotionSampleBatch] {
        var samples: [MotionSampleBatch] = []

        for i in 0..<count {
            let index = startIndex + i
            updatePhase(for: gestureType, collected: startIndex + i, collecting: count - i)

            if let batch = await recordSingleSample(gestureType: gestureType, index: index) {
                samples.append(batch)
            }
        }

        return samples
    }

    private func recordSingleSample(gestureType: GestureLabel, index: Int) async -> MotionSampleBatch? {
        // Vänta på att Watch är klar med föregående inspelning innan vi startar en ny
        // Detta förhindrar race condition där Phone skickar startRecording innan Watch är redo
        var waitAttempts = 0
        let maxWaitAttempts = 100 // 10 sekunder max (100ms per försök)

        while isRecordingInProgress && waitAttempts < maxWaitAttempts {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            waitAttempts += 1
        }

        if isRecordingInProgress {
            print("[PhoneCalibrationManager] Watch still recording after timeout, aborting sample \(gestureType) #\(index)")
            return nil
        }

        // Skicka startkommando till Watch
        watchSession.sendCalibrationMessage(.startRecording(gestureType: gestureType, sampleIndex: index))

        // Vänta på svar med timeout
        return await withCheckedContinuation { continuation in
            currentRecordingContinuation = continuation

            // Timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(Config.recordingTimeoutSeconds * 1_000_000_000))
                if currentRecordingContinuation != nil {
                    print("[PhoneCalibrationManager] Recording timeout for \(gestureType) #\(index)")
                    resumeRecordingContinuation(with: nil)
                }
            }
        }
    }

    // MARK: - Analysis & Save

    private func analyzeAndSave() async {
        phase = .analyzing

        // Konvertera till templates
        var templates: [GestureTemplate] = []

        templates.append(contentsOf: outlierDetector.toTemplates(
            OutlierDetector.AnalysisResult(
                kept: forwardSamples,
                removed: [],
                averageDistances: [],
                medianDistance: 0,
                variance: 0
            ),
            label: .flickForward
        ))

        templates.append(contentsOf: outlierDetector.toTemplates(
            OutlierDetector.AnalysisResult(
                kept: backwardSamples,
                removed: [],
                averageDistances: [],
                medianDistance: 0,
                variance: 0
            ),
            label: .flickBackward
        ))

        templates.append(contentsOf: outlierDetector.toTemplates(
            OutlierDetector.AnalysisResult(
                kept: negativeSamples,
                removed: [],
                averageDistances: [],
                medianDistance: 0,
                variance: 0
            ),
            label: .negative
        ))

        // Spara till App Group
        templateStore.save(templates)

        // Visa statistik
        let stats = CalibrationStats(
            forwardKept: forwardSamples.count,
            forwardRemoved: 0,
            backwardKept: backwardSamples.count,
            backwardRemoved: 0,
            negativeKept: negativeSamples.count,
            negativeRemoved: 0
        )

        phase = .complete(stats: stats)
        print("[PhoneCalibrationManager] Calibration complete: \(templates.count) templates saved")
    }

    // MARK: - UI Helpers

    private func updatePhase(for gestureType: GestureLabel, collected: Int, collecting: Int) {
        let target = collected + collecting
        switch gestureType {
        case .flickForward:
            phase = .collectingForward(collected: collected, target: target)
            progress = Double(collected) / Double(Config.maxSamplesPerType)
        case .flickBackward:
            phase = .collectingBackward(collected: collected, target: target)
            progress = (Double(Config.maxSamplesPerType) + Double(collected)) / Double(Config.maxSamplesPerType * 2 + Config.negativeSamplesTarget)
        case .negative:
            phase = .collectingNegative(collected: collected, target: Config.negativeSamplesTarget)
        }
    }
}

// MARK: - GestureTemplateStore (Phone-side)

/// Lagrar gestmallar i App Group för delning med Watch.
private final class GestureTemplateStore {
    private let appGroupID = "group.com.kristianniemi.FlickSlides"
    private let key = "gestureTemplates"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    func save(_ templates: [GestureTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else {
            print("[GestureTemplateStore] Failed to encode templates")
            return
        }
        defaults.set(data, forKey: key)
        print("[GestureTemplateStore] Saved \(templates.count) templates")
    }

    func load() -> [GestureTemplate] {
        guard let data = defaults.data(forKey: key),
              let templates = try? JSONDecoder().decode([GestureTemplate].self, from: data) else {
            return []
        }
        return templates
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    var hasTemplates: Bool {
        defaults.data(forKey: key) != nil
    }
}
