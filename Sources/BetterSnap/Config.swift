import Foundation
import BetterSnapCore

struct Config: Codable {
    var modifiers: ModifierSet = .option
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
