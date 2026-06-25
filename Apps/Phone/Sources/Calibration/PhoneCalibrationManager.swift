import Foundation
import FlickSlidesKit
import WatchConnectivity

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
        static let initialBatchSize = 3          // Minimal batch - snabb kalibrering
        static let additionalBatchSize = 2       // Extra samples vid behov
        static let minSamplesRequired = 3        // Minimum för att godkänna
        static let maxSamplesPerType = 5         // Max totalt per gest-typ
        static let recordingTimeoutSeconds = 10.0
        // Negativa samples tas bort - använd threshold-baserad filtrering istället
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
        minSamplesToKeep: 3,
        maxSamplesToKeep: 5
    )
    private let templateStore = GestureTemplateStore()

    // MARK: - Private State

    private var forwardSamples: [MotionSampleBatch] = []
    private var backwardSamples: [MotionSampleBatch] = []

    private var currentRecordingContinuation: CheckedContinuation<MotionSampleBatch?, Never>?
    private var isRecordingInProgress = false

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

        phase = .intro
        progress = 0

        // Vänta på att Watch är redo
        await waitForWatch()

        guard isWatchReady else {
            phase = .error(message: "Watch ej tillgänglig")
            return
        }

        // Samla Forward-gester
        await collectGestureType(.flickForward, prompt: "Gör en NÄSTA-gest (flicka framåt)")

        // Samla Backward-gester
        await collectGestureType(.flickBackward, prompt: "Gör en FÖREGÅENDE-gest (flicka bakåt)")

        // Negativa samples skippas - threshold-baserad filtrering används istället
        // för att undvika false positives. Detta ger snabbare kalibrering (~30 sek).

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
        // Begär kalibrering - visar dialog på Watch
        watchSession.sendCalibrationMessage(.calibrationRequested)

        // Vänta på svar (max 30 sekunder - användaren behöver tid att svara)
        for _ in 0..<300 {
            if isWatchReady { return }
            if case .error = phase { return } // Avbryt om användaren avvisade
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }

    private func handleWatchMessage(_ message: CalibrationMessage) {
        switch message {
        case .calibrationAccepted, .pong, .watchReady:
            isWatchReady = true

        case .calibrationDeclined:
            isWatchReady = false
            phase = .error(message: "Kalibrering avvisades på klockan")

        case .watchDismissed:
            isWatchReady = false
            isRecordingInProgress = false
            isWaitingForIdle = false
            isReadyForGesture = false
            // Avbryt pågående continuations
            resumeRecordingContinuation(with: nil)
            readyForGestureContinuation?.resume()
            readyForGestureContinuation = nil
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
        case .calibrationRequested, .startRecording, .stopRecording, .calibrationAborted, .calibrationComplete, .ping:
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
        // 1. Vänta på att föregående inspelning är helt klar
        var waitAttempts = 0
        let maxWaitAttempts = 100 // 10 sekunder max

        while isRecordingInProgress && waitAttempts < maxWaitAttempts {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            waitAttempts += 1
        }

        if isRecordingInProgress {
            print("[PhoneCalibrationManager] Watch still recording, waiting more...")
            // Skicka stopRecording för att tvinga Watch att avsluta
            watchSession.sendCalibrationMessage(.stopRecording)
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            isRecordingInProgress = false
        }

        // 2. Kort paus så användaren hinner se prompten
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // 3. Skicka startkommando till Watch
        print("[PhoneCalibrationManager] Starting recording for \(gestureType) #\(index)")
        watchSession.sendCalibrationMessage(.startRecording(gestureType: gestureType, sampleIndex: index))

        // 4. Vänta på readyForGesture (Watch detekterar att armen är vilande)
        var readyWaitAttempts = 0
        let maxReadyWaitAttempts = 150 // 15 sekunder för idle-detektion

        while !isReadyForGesture && isRecordingInProgress && readyWaitAttempts < maxReadyWaitAttempts {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            readyWaitAttempts += 1
        }

        if !isReadyForGesture && isRecordingInProgress {
            print("[PhoneCalibrationManager] Timeout waiting for idle, continuing anyway for \(gestureType) #\(index)")
        } else if isReadyForGesture {
            print("[PhoneCalibrationManager] User ready for gesture \(gestureType) #\(index)")
        }

        // 5. Vänta på sampleRecorded
        return await withCheckedContinuation { continuation in
            currentRecordingContinuation = continuation

            // Timeout för själva gesten (efter idle)
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

        // Konvertera till templates (endast forward och backward)
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

        // Spara till App Group (lokal backup)
        templateStore.save(templates)

        // Överför mallar till Watch via WCSession
        do {
            let data = try JSONEncoder().encode(templates)
            WCSession.default.transferUserInfo(["gestureTemplates": data])
            print("[PhoneCalibrationManager] Transferred \(templates.count) templates to Watch")
        } catch {
            print("[PhoneCalibrationManager] Failed to encode templates for transfer: \(error)")
        }

        // Meddela Watch att kalibreringen är klar
        watchSession.sendCalibrationMessage(.calibrationComplete)

        // Visa statistik
        let stats = CalibrationStats(
            forwardKept: forwardSamples.count,
            forwardRemoved: 0,
            backwardKept: backwardSamples.count,
            backwardRemoved: 0,
            negativeKept: 0,
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
            progress = Double(collected) / Double(Config.maxSamplesPerType * 2)
        case .flickBackward:
            phase = .collectingBackward(collected: collected, target: target)
            progress = (Double(Config.maxSamplesPerType) + Double(collected)) / Double(Config.maxSamplesPerType * 2)
        case .negative:
            // Negativa samples skippas i minimal kalibrering
            break
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
