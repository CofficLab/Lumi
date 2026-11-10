import Foundation
import LumiLocalizationKit
import ProviderConversation

/// 会话设置面板里的详细度显示名。
///
/// - Important: `ProviderConversation.ResponseVerbosity` **不再**产出任何语言的
///   显示名（#920 把硬编码文案迁到了各插件自己的字符串目录）。
///   `PluginConversationManager` 不依赖 `PluginConversationVerbosity`
///   （插件不得依赖插件），因此在这里维护自己的一份映射。
///
///   - Note: 断言语义与 `PluginConversationVerbosity` 的本地化保持一致，
///     但两者是**各自独立**的目录副本。
extension ResponseVerbosity {
    /// 本插件目录里的显示名键。
    var settingsDisplayNameKey: String {
        switch self {
        case .brief: "Verbosity Brief"
        case .standard: "Verbosity Standard"
        case .detailed: "Verbosity Detailed"
        // V4 是 ZCode 风格消息列表的呈现变体。
        case .zcode: "Verbosity ZCode"
        }
    }

    /// 本地化后的显示名。
    func localizedSettingsDisplayName(
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        resolve(settingsDisplayNameKey)
    }
}
