import Foundation
import LumiLocalizationKit
import ProviderConversation

/// 详细度控件的用户可见文案。
///
/// 文案属于界面层，由插件本地化目录维护；`ProviderConversation` 只负责行为，
/// 不再产出任何语言的显示名（#920）。
extension ResponseVerbosity {
    var displayNameKey: String {
        switch self {
        case .brief: "Brief"
        case .standard: "Standard"
        case .detailed: "Detailed"
        }
    }

    var descriptionKey: String {
        switch self {
        case .brief: "Brief Description"
        case .standard: "Standard Description"
        case .detailed: "Detailed Description"
        }
    }

    func localizedDisplayName(
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        resolve(displayNameKey)
    }

    func localizedDescription(
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        resolve(descriptionKey)
    }
}
