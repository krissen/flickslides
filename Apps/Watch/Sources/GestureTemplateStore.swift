import Foundation

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

    // MARK: - Public API

    func save(_ templates: [DTWMatcher.GestureTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else {
            print("[GestureTemplateStore] Failed to encode templates")
            return
        }
        defaults.set(data, forKey: key)
        print("[GestureTemplateStore] Saved \(templates.count) templates")
    }

    func load() -> [DTWMatcher.GestureTemplate] {
        guard let data = defaults.data(forKey: key),
              let templates = try? JSONDecoder().decode([DTWMatcher.GestureTemplate].self, from: data) else {
            return []
        }
        print("[GestureTemplateStore] Loaded \(templates.count) templates")
        return templates
    }

    func clear() {
        defaults.removeObject(forKey: key)
        print("[GestureTemplateStore] Cleared all templates")
    }

    var hasTemplates: Bool {
        defaults.data(forKey: key) != nil
    }

    var templateCount: Int {
        load().count
    }
}
