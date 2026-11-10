import Foundation
import LumiLocalizationKit
import ProviderConversation

/// 自动化等级控件的用户可见文案。
///
/// 文案属于界面层，由插件本地化目录维护；控件不再直接读取
/// `AutomationLevel` 中写死的中文属性（#919）。
extension AutomationLevel {
    var displayNameKey: String {
        switch self {
        case .chat: "Chat"
        case .build: "Build"
        case .autonomous: "Autonomous"
        }
    }

    var descriptionKey: String {
        switch self {
        case .chat: "Chat Description"
        case .build: "Build Description"
        case .autonomous: "Autonomous Description"
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
