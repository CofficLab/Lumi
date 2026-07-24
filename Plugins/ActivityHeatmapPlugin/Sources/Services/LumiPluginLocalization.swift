import Foundation

/// Self-contained localization helper for ActivityHeatmapPlugin.
/// Does not depend on LumiLocalizationKit — falls back to the key itself when no bundle is found.
public enum LumiPluginLocalization {
    /// Returns the localized string for the given key, or the key itself if not found.
    public static func string(_ key: String, bundle: Bundle) -> String {
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        // If the value equals the key, the string wasn't found → return the key itself.
        return value == key ? key : value
    }
}
