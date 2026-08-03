import Foundation
import LocalizationKit

/// Runtime localization for StoryWriterPlugin bundle.
///
/// Provides localization lookup scoped to this plugin by delegating to LumiLocalization.
public enum LumiPluginLocalization {
    public static let table = "Localizable"

    public static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: Bundle.module, table: table)
    }
}
