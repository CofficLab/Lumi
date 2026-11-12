import Foundation
import LumiUI

/// 工具授权卡片的用户决定。
///
/// 由答案文本反推：授权卡片上的按钮文案既有中文也有英文，
/// 生产者与本地化都可能变化，所以判定必须覆盖两套词表。
enum ToolApprovalAction: Equatable {
    case allow
    case alwaysAllow
    case reject
    case other

    static let alwaysAllowLabel = "始终允许"

    init(answer: String) {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "允许", "同意", "是", "allow", "approve", "approved", "yes":
            self = .allow
        case "始终允许", "always allow", "always_allow":
            self = .alwaysAllow
        case "拒绝", "否", "deny", "reject", "no":
            self = .reject
        default:
            self = .other
        }
    }

    var buttonStyle: AppButton.Style {
        switch self {
        case .allow:
            .primary
        case .alwaysAllow:
            .warning
        case .reject, .other:
            .destructive
        }
    }

    var systemImage: String {
        switch self {
        case .allow:
            "checkmark.circle.fill"
        case .alwaysAllow:
            "bolt.shield.fill"
        case .reject, .other:
            "xmark.circle.fill"
        }
    }

    /// 该决定对应的无障碍标识符。
    ///
    /// UI 测试必须按标识符定位按钮，而不是按文案：按钮文案是随
    /// `-AppleLanguages` 变化的本地化文本，按文案定位在非英文环境下必然失败。
    var accessibilityIdentifier: String {
        switch self {
        case .allow:
            ToolApprovalAccessibility.allow
        case .alwaysAllow:
            ToolApprovalAccessibility.alwaysAllow
        case .reject:
            ToolApprovalAccessibility.reject
        case .other:
            ToolApprovalAccessibility.other
        }
    }
}
