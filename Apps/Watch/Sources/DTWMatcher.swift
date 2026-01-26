import Foundation
import FlickSlidesKit

/// Dynamic Time Warping för gestmatchning.
///
/// DTW-algoritmen jämför tidsserier av olika längd genom att hitta den optimala
/// "warping"-vägen som minimerar avståndet mellan sekvenserna.
final class DTWMatcher {

    // MARK: - Types

    struct MatchResult {
        let label: GestureLabel?
        let confidence: Double  // 0.0 - 1.0
        let distance: Double
    }

    // MARK: - Constants

    /// Absolut avståndströskel som fallback när inga negativa mallar finns.
    /// Värdet är baserat på typiska DTW-avstånd för korrekta gestmatchningar.
    private static let absoluteDistanceThreshold: Double = 15.0

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

        // Validera att vi har mallar för den matchade labeln
        // (skyddar mot edge case där averagedForward/Backward existerar men utan underliggande mallar)
        if let label = bestLabel {
            let hasTemplatesForLabel = templates.contains { $0.label == label }
            guard hasTemplatesForLabel else {
                return MatchResult(label: nil, confidence: 0, distance: bestDistance)
            }
        }

        // Jämför med negativa mallar
        let negativeTemplates = templates.filter { $0.label == .negative }
        var minNegativeDistance = Double.infinity
        for template in negativeTemplates {
            let distance = dtwDistance(gesture, template.samples)
            minNegativeDistance = min(minNegativeDistance, distance)
        }

        // Bestäm tröskel: använd negativa mallar om de finns, annars absolut tröskel
        let hasNegativeTemplates = !negativeTemplates.isEmpty
        let threshold: Double
        let margin = 0.7  // 30% marginal

        if hasNegativeTemplates {
            // Om vi har negativa mallar, kräv att positiv match är betydligt bättre
            threshold = minNegativeDistance * margin
        } else {
            // Utan negativa mallar: använd absolut tröskel som fallback
            // Detta förhindrar att DTW godkänner ALLA gester
            threshold = Self.absoluteDistanceThreshold
        }

        // Kontrollera om bästa match passerar tröskeln
        if bestDistance < threshold {
            // Beräkna confidence: normalisera till 0.0-1.0
            // confidence = 1.0 vid bestDistance = 0, avtar mot 0.0 vid threshold
            let normalizedDistance = bestDistance / threshold
            let confidence = max(0.0, min(1.0, 1.0 - normalizedDistance))

            return MatchResult(label: bestLabel, confidence: confidence, distance: bestDistance)
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

        // Guard: om maxLength == 1 kan vi inte interpolera, returnera första samplet direkt
        // Detta förhindrar division by zero i indexberäkningen nedan
        if maxLength == 1 {
            // Samla alla första samples och beräkna medelvärde
            var sumAccX = 0.0, sumAccY = 0.0, sumAccZ = 0.0
            var sumRotX = 0.0, sumRotY = 0.0, sumRotZ = 0.0
            var sumTime = 0.0

            for seq in sequences where !seq.isEmpty {
                let sample = seq[0]
                sumAccX += sample.accX
                sumAccY += sample.accY
                sumAccZ += sample.accZ
                sumRotX += sample.rotX
                sumRotY += sample.rotY
                sumRotZ += sample.rotZ
                sumTime += sample.timestamp
            }

            let count = Double(sequences.filter { !$0.isEmpty }.count)
            guard count > 0 else { return nil }

            return [MotionSample(
                timestamp: sumTime / count,
                accX: sumAccX / count,
                accY: sumAccY / count,
                accZ: sumAccZ / count,
                rotX: sumRotX / count,
                rotY: sumRotY / count,
                rotZ: sumRotZ / count
            )]
        }

        var result: [MotionSample] = []

        for i in 0..<maxLength {
            var sumAccX = 0.0, sumAccY = 0.0, sumAccZ = 0.0
            var sumRotX = 0.0, sumRotY = 0.0, sumRotZ = 0.0
            var sumTime = 0.0
            var count = 0

            for seq in sequences {
                // Interpolera index för sekvenser av olika längd
                // Säker division: maxLength > 1 garanterat av guard ovan
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
