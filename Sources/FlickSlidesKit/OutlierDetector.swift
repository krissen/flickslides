import Foundation

/// Detekterar och tar bort outliers från gest-samples med DTW-baserad analys.
///
/// Algoritmen beräknar pairwise DTW-avstånd mellan alla samples och identifierar
/// de som har ovanligt högt genomsnittligt avstånd till övriga samples.
public struct OutlierDetector: Sendable {

    // MARK: - Configuration

    /// Multiplikator för median-avstånd för att avgöra outlier-tröskel.
    /// Samples med genomsnittligt avstånd > median × threshold anses vara outliers.
    public let outlierThreshold: Double

    /// Minsta antal samples att behålla per gest-typ.
    public let minSamplesToKeep: Int

    /// Maximalt antal samples att behålla per gest-typ.
    public let maxSamplesToKeep: Int

    // MARK: - Initialization

    public init(
        outlierThreshold: Double = 1.5,
        minSamplesToKeep: Int = 8,
        maxSamplesToKeep: Int = 15
    ) {
        self.outlierThreshold = outlierThreshold
        self.minSamplesToKeep = minSamplesToKeep
        self.maxSamplesToKeep = maxSamplesToKeep
    }

    // MARK: - Outlier Detection

    /// Resultat från outlier-analys för en grupp samples.
    public struct AnalysisResult: Sendable {
        public let kept: [MotionSampleBatch]
        public let removed: [MotionSampleBatch]
        public let averageDistances: [Double]
        public let medianDistance: Double
        public let variance: Double

        public init(
            kept: [MotionSampleBatch],
            removed: [MotionSampleBatch],
            averageDistances: [Double],
            medianDistance: Double,
            variance: Double
        ) {
            self.kept = kept
            self.removed = removed
            self.averageDistances = averageDistances
            self.medianDistance = medianDistance
            self.variance = variance
        }

        public var varianceIsHigh: Bool {
            // Hög varians om standardavvikelsen är > 30% av median
            let stdDev = sqrt(variance)
            return medianDistance > 0 && stdDev / medianDistance > 0.3
        }
    }

    /// Analyserar samples och tar bort outliers.
    public func analyze(_ samples: [MotionSampleBatch]) -> AnalysisResult {
        guard samples.count > 2 else {
            return AnalysisResult(
                kept: samples,
                removed: [],
                averageDistances: [],
                medianDistance: 0,
                variance: 0
            )
        }

        // Beräkna pairwise DTW-avstånd
        let distances = pairwiseDistances(samples)

        // Beräkna genomsnittligt avstånd för varje sample
        var avgDistances: [Double] = []
        for i in 0..<samples.count {
            var sum = 0.0
            var count = 0
            for j in 0..<samples.count where i != j {
                sum += distances[min(i, j)][max(i, j)]
                count += 1
            }
            avgDistances.append(count > 0 ? sum / Double(count) : 0)
        }

        // Beräkna median-avstånd
        let sortedDistances = avgDistances.sorted()
        let median = sortedDistances[sortedDistances.count / 2]

        // Beräkna varians
        let mean = avgDistances.reduce(0, +) / Double(avgDistances.count)
        let variance = avgDistances.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(avgDistances.count)

        // Identifiera outliers (avstånd > median × threshold)
        let threshold = median * outlierThreshold
        var indexedSamples = samples.enumerated().map { ($0.offset, $0.element, avgDistances[$0.offset]) }

        // Sortera efter avstånd (lägst först = bäst)
        indexedSamples.sort { $0.2 < $1.2 }

        // Behåll de bästa samples
        var kept: [MotionSampleBatch] = []
        var removed: [MotionSampleBatch] = []

        for (_, sample, distance) in indexedSamples {
            if kept.count < minSamplesToKeep {
                // Behåll minst minSamplesToKeep
                kept.append(sample)
            } else if distance > threshold && kept.count >= minSamplesToKeep {
                // Ta bort outliers (men bara om vi har tillräckligt)
                removed.append(sample)
            } else if kept.count < maxSamplesToKeep {
                // Behåll upp till maxSamplesToKeep
                kept.append(sample)
            } else {
                // Har tillräckligt, ta bort övriga
                removed.append(sample)
            }
        }

        return AnalysisResult(
            kept: kept,
            removed: removed,
            averageDistances: avgDistances,
            medianDistance: median,
            variance: variance
        )
    }

    /// Beräknar fullständig outlier-analys för alla gest-typer.
    public func analyzeAll(
        forward: [MotionSampleBatch],
        backward: [MotionSampleBatch],
        negative: [MotionSampleBatch]
    ) -> (forward: AnalysisResult, backward: AnalysisResult, negative: AnalysisResult) {
        return (
            forward: analyze(forward),
            backward: analyze(backward),
            negative: analyze(negative)
        )
    }

    /// Kontrollerar om vi behöver fler samples baserat på analys-resultat.
    public func needsMoreSamples(_ result: AnalysisResult, targetCount: Int) -> Bool {
        return result.kept.count < targetCount || result.varianceIsHigh
    }

    // MARK: - DTW Algorithm

    /// Beräknar pairwise DTW-avstånd mellan alla samples.
    /// Returnerar en triangulär matris där [i][j] (i < j) innehåller avståndet.
    private func pairwiseDistances(_ samples: [MotionSampleBatch]) -> [[Double]] {
        var distances: [[Double]] = Array(repeating: [], count: samples.count)

        for i in 0..<samples.count {
            distances[i] = Array(repeating: 0, count: samples.count)
            for j in (i + 1)..<samples.count {
                let distance = dtwDistance(samples[i].samples, samples[j].samples)
                distances[i][j] = distance
            }
        }

        return distances
    }

    /// Beräknar DTW-avstånd mellan två sekvenser.
    private func dtwDistance(_ s1: [MotionSample], _ s2: [MotionSample]) -> Double {
        let n = s1.count
        let m = s2.count

        guard n > 0 && m > 0 else { return .infinity }

        // Använd Sakoe-Chiba band för att begränsa beräkningen
        let window = max(n, m) / 3

        // Skapa matris
        var matrix = [[Double]](repeating: [Double](repeating: .infinity, count: m + 1), count: n + 1)
        matrix[0][0] = 0

        for i in 1...n {
            let jMin = max(1, i - window)
            let jMax = min(m, i + window)
            guard jMin <= jMax else { continue }
            for j in jMin...jMax {
                let cost = sampleDistance(s1[i - 1], s2[j - 1])
                matrix[i][j] = cost + min(
                    matrix[i - 1][j],     // insertion
                    matrix[i][j - 1],     // deletion
                    matrix[i - 1][j - 1]  // match
                )
            }
        }

        // Normalisera med path-längd
        return matrix[n][m] / Double(n + m)
    }

    /// Beräknar euklidiskt avstånd mellan två motion samples.
    private func sampleDistance(_ a: MotionSample, _ b: MotionSample) -> Double {
        let arr1 = a.asArray
        let arr2 = b.asArray

        var sum = 0.0
        for i in 0..<arr1.count {
            let diff = arr1[i] - arr2[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
}

// MARK: - Batch to Template Conversion

extension OutlierDetector {

    /// Konverterar behållna batches till GestureTemplate.
    public func toTemplates(
        _ result: AnalysisResult,
        label: GestureLabel
    ) -> [GestureTemplate] {
        result.kept.map { batch in
            GestureTemplate(label: label, samples: batch.samples, createdAt: batch.recordedAt)
        }
    }
}
