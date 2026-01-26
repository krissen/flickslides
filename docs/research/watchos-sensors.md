# watchOS Sensor-research: Apple Watch Ultra 1

## 1. Hårdvaruöversikt: Ultra 1 vs Series 9/10

| Egenskap | Ultra 1 | Series 9/10 | Ultra 2 |
|----------|---------|-------------|---------|
| **Chip** | S8 | S9/S10 | S9 |
| **Double Tap API** | **NEJ** | Ja | Ja |
| **Neural Engine (4-core)** | Nej | Ja | Ja |
| **Accelerometer** | Ja (256g) | Ja | Ja (256g) |
| **Gyroscope** | Ja | Ja | Ja |
| **Action Button** | Ja | Nej | Ja |
| **CoreMotion** | Full | Full | Full |
| **handGestureShortcut** | **Ignoreras** | Full | Full |

---

## 2. CoreMotion API på watchOS 11

### 2.1 CMMotionManager

**Tillgänglighet:** watchOS 2.0+, fullt stödd på watchOS 11

CMMotionManager ger tillgång till:

- **Accelerometer** - Mäter linjär acceleration i x, y, z (inkl. gravitation)
- **Gyroscope** - Mäter rotationshastighet (rad/s)
- **Device Motion** (REKOMMENDERAS) - Fusionerad data som separerar `userAcceleration` från `gravity`

### 2.2 CMDeviceMotion-egenskaper

```swift
struct CMDeviceMotion {
    var attitude: CMAttitude           // Roll, pitch, yaw
    var rotationRate: CMRotationRate   // Gyro-data (rad/s)
    var gravity: CMAcceleration        // Gravitationsvektor
    var userAcceleration: CMAcceleration  // Rörelseacceleration (exkl. gravitation)
}
```

**Rekommendation:** 50 Hz sampling för FlickSlides (balans mellan precision och batteri)

---

## 3. handGestureShortcut(.primaryAction) - BEKRÄFTAD BEGRÄNSNING

### 3.1 API-specifikation

```swift
// watchOS 10.0+
extension View {
    func handGestureShortcut(_ shortcut: HandGestureShortcut) -> some View
}
```

### 3.2 Hårdvarukrav - KRITISKT

`handGestureShortcut(.primaryAction)` kräver **Double Tap-kapabilitet**, vilket endast finns på klockor med **S9-chip eller senare**:

| Modell | Stöd |
|--------|------|
| Series 9 (S9) | **JA** |
| Series 10 (S10) | **JA** |
| Ultra 2 (S9) | **JA** |
| **Ultra 1 (S8)** | **NEJ** |

### 3.3 Beteende på Ultra 1

- **Kompilerar utan fel** - API:et finns i SDK:n
- **Körs utan krasch** - Modifiern ignoreras tyst
- **Ingen effekt** - Double Tap-gesten triggar aldrig

**Slutsats:** Vi måste implementera egen gestdetektering via CoreMotion.

---

## 4. HKWorkoutSession för bakgrundsaktivitet

### 4.1 Varför behövs det?

watchOS pausar bakgrundsappar aggressivt. För att hålla sensorer aktiva under en presentation måste vi använda HKWorkoutSession.

### 4.2 Krav

1. **HealthKit Capability** i Xcode
2. **Info.plist-nycklar:**
   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>FlickSlides uses workout sessions to keep gesture detection active.</string>
   <key>NSHealthUpdateUsageDescription</key>
   <string>FlickSlides uses workout sessions to keep gesture detection active.</string>
   ```
3. **Workout Processing** bakgrundsläge

### 4.3 Begränsningar och risker

- Workout-ikonen visas på urtavlan
- Apple kan avvisa appar som "missbrukar" workout sessions
- **Risknivå:** Medel - många appar använder detta för sensortillgång

---

## 5. Prototypkod

### 5.1 GestureDetector.swift

```swift
import Foundation
import CoreMotion

/// Gestigenkänning baserad på accelerometer/gyroskop-data.
@MainActor
final class GestureDetector: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isActive = false
    @Published private(set) var lastDetectedGesture: DetectedGesture?
    @Published private(set) var currentAcceleration: Double = 0

    // MARK: - Configuration

    struct Configuration {
        var accelerationThreshold: Double = 0.8  // g
        var rotationThreshold: Double = 18.0     // degrees
        var debounceInterval: TimeInterval = 1.0  // seconds
        var samplingRate: Double = 50.0          // Hz
    }

    var configuration = Configuration()

    // MARK: - Detected Gesture

    enum DetectedGesture: Equatable {
        case flick(direction: FlickDirection)
        case doublePunch

        enum FlickDirection {
            case forward   // Nästa slide
            case backward  // Föregående slide
        }
    }

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private var lastGestureTime: Date = .distantPast
    private var onGestureDetected: ((DetectedGesture) -> Void)?
    private var recentAccelerations: [Double] = []
    private let peakWindowSize = 10

    // MARK: - Public Methods

    func start(onGesture: @escaping (DetectedGesture) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        onGestureDetected = onGesture

        let interval = 1.0 / configuration.samplingRate
        motionManager.deviceMotionUpdateInterval = interval

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            Task { @MainActor in
                self.processMotion(motion)
            }
        }

        isActive = true
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        onGestureDetected = nil
        recentAccelerations.removeAll()
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        let acc = motion.userAcceleration
        let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        currentAcceleration = magnitude

        recentAccelerations.append(magnitude)
        if recentAccelerations.count > peakWindowSize {
            recentAccelerations.removeFirst()
        }

        let now = Date()
        guard now.timeIntervalSince(lastGestureTime) > configuration.debounceInterval else {
            return
        }

        if magnitude > configuration.accelerationThreshold && isPeak(magnitude) {
            let direction = determineDirection(acc)
            let gesture = DetectedGesture.flick(direction: direction)

            lastGestureTime = now
            lastDetectedGesture = gesture
            onGestureDetected?(gesture)
        }
    }

    private func isPeak(_ value: Double) -> Bool {
        guard recentAccelerations.count >= 3 else { return false }
        let lastIndex = recentAccelerations.count - 1
        return value >= recentAccelerations[lastIndex - 1] &&
               value >= recentAccelerations[lastIndex - 2]
    }

    private func determineDirection(_ acc: CMAcceleration) -> DetectedGesture.FlickDirection {
        return acc.x > 0 ? .forward : .backward
    }
}
```

### 5.2 PresentationManager.swift

```swift
import Foundation
import HealthKit
import WatchConnectivity
import WatchKit

@MainActor
final class PresentationManager: NSObject, ObservableObject {

    static let shared = PresentationManager()

    @Published private(set) var isPresentationMode = false
    @Published private(set) var connectionState: String = "Not connected"
    @Published private(set) var lastCommand: String?

    private let gestureDetector = GestureDetector()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
        setupWCSession()
    }

    private func setupWCSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func startPresentation() async {
        guard !isPresentationMode else { return }

        do {
            try await startWorkoutSession()
        } catch {
            print("Failed to start workout: \(error)")
        }

        gestureDetector.start { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }

        isPresentationMode = true
        WKInterfaceDevice.current().play(.start)
    }

    func stopPresentation() async {
        guard isPresentationMode else { return }

        gestureDetector.stop()

        if let session = workoutSession {
            session.end()
            workoutSession = nil
        }

        isPresentationMode = false
        WKInterfaceDevice.current().play(.stop)
    }

    private func startWorkoutSession() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        workoutSession = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        workoutSession?.startActivity(with: Date())
        try await workoutBuilder?.beginCollection(at: Date())
    }

    private func handleGesture(_ gesture: GestureDetector.DetectedGesture) {
        let command: String

        switch gesture {
        case .flick(let direction):
            command = direction == .forward ? "NEXT" : "PREV"
        case .doublePunch:
            command = "BLACKOUT"
        }

        sendCommand(command)
        WKInterfaceDevice.current().play(.success)
    }

    private func sendCommand(_ command: String) {
        guard WCSession.default.isReachable else {
            connectionState = "iPhone not reachable"
            return
        }

        WCSession.default.sendMessage(["command": command], replyHandler: { _ in
            Task { @MainActor in
                self.lastCommand = command
            }
        }, errorHandler: { error in
            Task { @MainActor in
                self.connectionState = "Send failed"
            }
        })
    }
}

extension PresentationManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            connectionState = activationState == .activated ? "Connected" : "Not connected"
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            connectionState = session.isReachable ? "Connected" : "Disconnected"
        }
    }
}
```

### 5.3 ContentView.swift

```swift
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

    private var statusSection: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(presentationManager.isPresentationMode ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(presentationManager.isPresentationMode ? "Active" : "Inactive")
                    .font(.caption)
            }
            Text(presentationManager.connectionState)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

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
                    ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                Text(presentationManager.isPresentationMode ? "Stop" : "Start")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(presentationManager.isPresentationMode ? .red : .green)
    }

    private var fallbackButtons: some View {
        HStack(spacing: 20) {
            Button {
                sendFallback("PREV")
            } label: {
                Image(systemName: "chevron.left").font(.title2)
            }
            .buttonStyle(.bordered)

            Button {
                sendFallback("NEXT")
            } label: {
                Image(systemName: "chevron.right").font(.title2)
            }
            .buttonStyle(.bordered)
        }
        .disabled(!presentationManager.isPresentationMode)
    }

    private func sendFallback(_ command: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["command": command], replyHandler: nil)
        WKInterfaceDevice.current().play(.click)
    }
}
```

---

## 6. Bekräftade begränsningar

| Begränsning | Påverkan | Lösning |
|-------------|----------|---------|
| Ultra 1 saknar Double Tap | Kan inte använda `handGestureShortcut` | Egen CoreMotion-detektion |
| CoreMotion pausas i bakgrund | Gester fungerar inte med låst skärm | HKWorkoutSession |
| WCSession kräver iPhone | Kan inte kommunicera direkt med Mac | iPhone som brygga |

---

## 7. Öppna frågor

1. **App Store-godkännande:** Kommer Apple att godkänna HKWorkoutSession-användning för gestdetektering? (Risk: Medel)

2. **Gestprecision:** Är tröskelbaserad detektion (0.8g) tillräckligt pålitlig, eller behöver vi CoreML?

3. **Batterilivslängd:** Hur länge räcker batteriet under aktiv session? (Mål: minst 2 timmar)

---

## 8. Nästa steg

1. Skapa Xcode-projekt med watchOS-target
2. Implementera prototypkoden ovan
3. Testa på fysisk Apple Watch Ultra 1
4. Samla in sensordata för olika gester
5. Justera tröskelvärden baserat på testning

---

## 9. Risker

1. **HKWorkoutSession-missbruk** kan leda till App Store-avslag
2. **False positives** vid naturlig gestikulering under presentation
3. **Batteriförbrukning** kan vara för hög för långa presentationer

---

## Appendix A: Sensorkoordinatsystem

```
         +Y (upp)
          |
          |
          |
    ------+------ +X (höger, mot kronan)
         /|
        / |
       /  |
      +Z (mot dig)

Apple Watch orientering:
- X-axel: Parallell med armbandet (positiv mot kronan)
- Y-axel: Uppåt längs klockan
- Z-axel: Ut från skärmen
```

---

## Appendix B: Typiska accelerationsvärden

| Rörelse | Typisk acceleration (g) |
|---------|------------------------|
| Stillastående | 0.0-0.1 |
| Normal gång | 0.3-0.5 |
| Gestikulering (samtal) | 0.4-0.7 |
| Avsiktlig flick | 0.8-2.0+ |
| Kraftig gest | 2.0-4.0 |

**Notering:** Dessa värden är approximativa och varierar mellan individer.

---

*Rapport skapad av watchOS-utvecklare*
*FlickSlides-projektet*
*Datum: 2025-01-25*
