import Foundation
import BetterSnapCore

struct Config: Codable {
    var modifiers: ModifierSet = .option
    var showsMenuBarIcon = true

    init() {}

    /// Hand-written so a field added later decodes as its default when an older blob
    /// lacks it. The synthesized decoder throws on a missing key instead, and `load`
    /// would then reset every other setting along with it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        modifiers = try container.decodeIfPresent(ModifierSet.self, forKey: .modifiers)
            ?? defaults.modifiers
        showsMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarIcon)
            ?? defaults.showsMenuBarIcon
    }
}

enum ConfigStore {
    private static let key = "config"

    /// A decode failure falls back to the default rather than propagating: a corrupt
    /// blob should cost you your modifier choice, not the whole app.
    static func load() -> Config {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let config = try? JSONDecoder().decode(Config.self, from: data)
        else {
            return Config()
        }
        return config
    }

    static func save(_ config: Config) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
