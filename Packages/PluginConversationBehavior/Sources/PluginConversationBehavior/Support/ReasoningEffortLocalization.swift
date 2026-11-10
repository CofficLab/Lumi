import Foundation
import LumiLocalizationKit
import ProviderConversation

/// 推理档位弹层的用户可见名称。
///
/// 文案属于界面层，由插件本地化目录维护；弹层不再直接读取
/// `ReasoningEffort` 中写死的中文属性（#918）。
extension ReasoningEffort {
    var displayNameKey: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .xhigh: "Extra High"
        case .max: "Max"
        }
    }

    func localizedDisplayName(
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        resolve(displayNameKey)
    }
}
