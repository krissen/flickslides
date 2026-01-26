import Foundation
import FlickSlidesKit

/// Lagrar och hämtar gestmallar från App Group UserDefaults.
///
/// Använder App Group för att dela data mellan Watch-appen och eventuellt
/// andra delar av appekosystemet (t.ex. iPhone-appen).
final class GestureTemplateStore {

    // MARK: - Constants

    private let appGroupID = "group.com.kristianniemi.FlickSlides"
    private let key = "gestureTemplates"

    // MARK: - Private Properties

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Cache för laddade mallar, invalideras vid save/clear
    private var cachedTemplates: [GestureTemplate]?

    // MARK: - Public API

    func save(_ templates: [GestureTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else {
            print("[GestureTemplateStore] Failed to encode templates")
            return
        }
        defaults.set(data, forKey: key)
        cachedTemplates = templates
        print("[GestureTemplateStore] Saved \(templates.count) templates")
    }

    func load() -> [GestureTemplate] {
        if let cached = cachedTemplates {
            return cached
        }
        guard let data = defaults.data(forKey: key),
              let templates = try? JSONDecoder().decode([GestureTemplate].self, from: data) else {
            cachedTemplates = []
            return []
        }
        cachedTemplates = templates
        print("[GestureTemplateStore] Loaded \(templates.count) templates")
        return templates
    }

    func clear() {
        defaults.removeObject(forKey: key)
        cachedTemplates = nil
        print("[GestureTemplateStore] Cleared all templates")
    }

    /// Returnerar true endast om det finns avkodningsbara mallar
    var hasTemplates: Bool {
        !load().isEmpty
    }

    /// Totalt antal mallar
    var templateCount: Int {
        load().count
    }

    /// Antal mallar per gesttyp
    var templateCountByLabel: [GestureLabel: Int] {
        let templates = load()
        return Dictionary(grouping: templates, by: \.label)
            .mapValues(\.count)
    }
}
