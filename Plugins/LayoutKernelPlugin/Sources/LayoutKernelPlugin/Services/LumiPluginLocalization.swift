import Foundation
import LocalizationKit

/// Runtime localization for LayoutKernelPlugin bundle.
public enum LumiPluginLocalization {
    public static func string(
        _ key: String,
        bundle: Bundle? = nil,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        guard let bundle else { return key }
        let value = bundle.localizedString(forKey: key, value: nil, table: table)
        return value == key ? key : value
    }
}
