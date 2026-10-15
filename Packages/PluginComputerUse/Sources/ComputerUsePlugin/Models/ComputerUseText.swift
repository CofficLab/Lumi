import Foundation

func computerUseText(_ key: String, _ values: [String: String] = [:]) -> String {
    values.reduce(pluginLocalization.string(key)) { text, entry in
        text.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
    }
}
