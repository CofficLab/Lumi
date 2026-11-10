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
        // V4 是 ZCode 风格消息列表的呈现变体。
        case .zcode: "ZCode"
        }
    }

    var descriptionKey: String {
        switch self {
        case .brief: "Brief Description"
        case .standard: "Standard Description"
        case .detailed: "Detailed Description"
        // V4 是呈现变体而非回复长度策略，因此描述只讲风格，不讲长短。
        case .zcode: "ZCode Description"
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
