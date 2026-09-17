import Foundation

func computerUseText(_ key: String, _ values: [String: String] = [:]) -> String {
    values.reduce(LumiPluginLocalization.string(key, bundle: .module)) { text, entry in
        text.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
    }
}
