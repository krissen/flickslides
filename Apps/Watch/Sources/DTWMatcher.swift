import Foundation

/// Dynamic Time Warping för gestmatchning.
///
/// DTW-algoritmen jämför tidsserier av olika längd genom att hitta den optimala
/// "warping"-vägen som minimerar avståndet mellan sekvenserna.
final class DTWMatcher {

    // MARK: - Types

    struct GestureTemplate: Codable, Identifiable {
        let id: UUID
        let label: GestureLabel
        let samples: [MotionSample]
        let createdAt: Date

        init(label: GestureLabel, samples: [MotionSample]) {
            self.id = UUID()
            self.label = label
            self.samples = samples
            self.createdAt = Date()
        }
    }

    enum GestureLabel: String, Codable, CaseIterable {
        case flickForward   // NEXT
        case flickBackward  // PREV
        case negative       // Inte en gest
    }

    struct MotionSample: Codable {
        let timestamp: TimeInterval  // Relativ till gestens start
        let accX: Double
        let accY: Double
        let accZ: Double
        let rotX: Double
        let rotY: Double
        let rotZ: Double

        var asArray: [Double] {
            [accX, accY, accZ, rotX, rotY, rotZ]
        }
    }

    struct MatchResult {
        let label: GestureLabel?
        let confidence: Double  // 0.0 - 1.0
        let distance: Double
    }

    // MARK: - Properties

    private var templates: [GestureTemplate] = []
    private var averagedForward: [MotionSample]?
    private var averagedBackward: [MotionSample]?

    var hasTemplates: Bool {
        !templates.isEmpty
    }

    var templateCount: [GestureLabel: Int] {
        Dictionary(grouping: templates, by: \.label).mapValues(\.count)
    }

    // MARK: - Template Management

    func addTemplate(_ template: GestureTemplate) {
        templates.append(template)
        recalculateAverages()
    }

    func clearTemplates() {
        templates.removeAll()
        averagedForward = nil
        averagedBackward = nil
    }

    func loadTemplates(_ templates: [GestureTemplate]) {
        self.templates = templates
        recalculateAverages()
    }

    func getTemplates() -> [GestureTemplate] {
        templates
    }

    // MARK: - Matching

    func match(_ gesture: [MotionSample]) -> MatchResult {
        guard hasTemplates else {
            return MatchResult(label: nil, confidence: 0, distance: .infinity)
        }

        var bestLabel: GestureLabel?
        var bestDistance = Double.infinity

        // Matcha mot genomsnittliga mallar
        if let forward = averagedForward {
            let distance = dtwDistance(gesture, forward)
            if distance < bestDistance {
                bestDistance = distance
                bestLabel = .flickForward
            }
        }

        if let backward = averagedBackward {
            let distance = dtwDistance(gesture, backward)
            if distance < bestDistance {
                bestDistance = distance
                bestLabel = .flickBackward
            }
        }

        // Jämför med negativa mallar
        let negativeTemplates = templates.filter { $0.label == .negative }
        var minNegativeDistance = Double.infinity
        for template in negativeTemplates {
            let distance = dtwDistance(gesture, template.samples)
            minNegativeDistance = min(minNegativeDistance, distance)
        }

        // Om bästa positiva match är betydligt bättre än negativa
        let margin = 0.7  // 30% marginal
        if bestDistance < minNegativeDistance * margin {
            let confidence = 1.0 - (bestDistance / max(minNegativeDistance, 1))
            return MatchResult(label: bestLabel, confidence: min(confidence, 1.0), distance: bestDistance)
        }

        return MatchResult(label: nil, confidence: 0, distance: bestDistance)
    }

    // MARK: - DTW Algorithm

    private func dtwDistance(_ s1: [MotionSample], _ s2: [MotionSample]) -> Double {
        let n = s1.count
        let m = s2.count

        guard n > 0 && m > 0 else { return .infinity }

        // Skapa matris
        var matrix = [[Double]](repeating: [Double](repeating: .infinity, count: m + 1), count: n + 1)
        matrix[0][0] = 0

        for i in 1...n {
            for j in 1...m {
                let cost = sampleDistance(s1[i-1], s2[j-1])
                matrix[i][j] = cost + min(
                    matrix[i-1][j],     // insertion
                    matrix[i][j-1],     // deletion
                    matrix[i-1][j-1]    // match
                )
            }
        }

        return matrix[n][m]
    }

    private func sampleDistance(_ a: MotionSample, _ b: MotionSample) -> Double {
        // Euklidiskt avstånd mellan sample-vektorer
        let arr1 = a.asArray
        let arr2 = b.asArray

        var sum = 0.0
        for i in 0..<arr1.count {
            let diff = arr1[i] - arr2[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }

    // MARK: - Averaging

    private func recalculateAverages() {
        let forwardTemplates = templates.filter { $0.label == .flickForward }
        let backwardTemplates = templates.filter { $0.label == .flickBackward }

        averagedForward = average(forwardTemplates.map(\.samples))
        averagedBackward = average(backwardTemplates.map(\.samples))
    }

    private func average(_ sequences: [[MotionSample]]) -> [MotionSample]? {
        guard !sequences.isEmpty else { return nil }

        // Använd längsta sekvensen som referens
        guard let maxLength = sequences.map(\.count).max(), maxLength > 0 else { return nil }

        var result: [MotionSample] = []

        for i in 0..<maxLength {
            var sumAccX = 0.0, sumAccY = 0.0, sumAccZ = 0.0
            var sumRotX = 0.0, sumRotY = 0.0, sumRotZ = 0.0
            var sumTime = 0.0
            var count = 0

            for seq in sequences {
                // Interpolera index för sekvenser av olika längd
                let idx = Int(Double(i) * Double(seq.count - 1) / Double(maxLength - 1))
                if idx < seq.count {
                    let sample = seq[idx]
                    sumAccX += sample.accX
                    sumAccY += sample.accY
                    sumAccZ += sample.accZ
                    sumRotX += sample.rotX
                    sumRotY += sample.rotY
                    sumRotZ += sample.rotZ
                    sumTime += sample.timestamp
                    count += 1
                }
            }

            if count > 0 {
                result.append(MotionSample(
                    timestamp: sumTime / Double(count),
                    accX: sumAccX / Double(count),
                    accY: sumAccY / Double(count),
                    accZ: sumAccZ / Double(count),
                    rotX: sumRotX / Double(count),
                    rotY: sumRotY / Double(count),
                    rotZ: sumRotZ / Double(count)
                ))
            }
        }

        return result
    }
}
