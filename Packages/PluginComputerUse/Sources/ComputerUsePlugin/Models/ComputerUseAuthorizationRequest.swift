import Foundation

/// 聊天内 Computer Use 授权卡片的用户决策。
///
/// 三个选项与设置界面的白名单语义一一对应：
/// - `allowOnce`：仅本次操作有效，不写入显式白名单；
/// - `alwaysAllow`：写入显式白名单，与设置界面「允许」共用同一份存储；
/// - `deny`：拒绝本次操作，agent 收到明确错误并停止该路径。
public enum ComputerUseAuthorizationDecision: String, Codable, Equatable, Sendable, CaseIterable {
    case allowOnce
    case alwaysAllow
    case deny

    /// 卡片上展示的按钮文案。
    public var displayTitle: String {
        switch self {
        case .allowOnce: return pluginLocalization.string("Allow Once")
        case .alwaysAllow: return pluginLocalization.string("Always Allow")
        case .deny: return pluginLocalization.string("Deny")
        }
    }

    /// 按钮图标。
    public var systemImage: String {
        switch self {
        case .allowOnce: return "checkmark.circle.fill"
        case .alwaysAllow: return "bolt.shield.fill"
        case .deny: return "xmark.circle.fill"
        }
    }

    /// 该决策是否放行本次操作。
    public var isApproved: Bool {
        self != .deny
    }
}

/// 授权请求载荷。
///
/// 由工具在命中未授权应用时生成，编码进 tool result 的 `content`，
/// 随回合挂起一起持久化；UI 从中恢复出卡片需要展示的信息。
public struct ComputerUseAuthorizationRequest: Codable, Equatable, Sendable {
    /// 载荷种类。与 `ToolApprovalBridge` 的 `kind` 约定保持一致，便于 UI 区分。
    public static let kind = "computer_use_authorization"

    /// 目标应用显示名。
    public let applicationName: String

    /// 目标应用 Bundle Identifier。
    public let bundleIdentifier: String

    /// 发起请求的操作描述（例如「观察 Safari 窗口」）。
    public let operation: String

    public init(applicationName: String, bundleIdentifier: String, operation: String) {
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.operation = operation
    }
}

/// 授权决策的解析与应用。
///
/// 决策字符串在 UI（卡片按钮）和工具（`resolveUserResponse`）之间传递，
/// 解析必须容忍空白、大小写和中英文表述，避免用户点错按钮就卡住回合。
public enum ComputerUseAuthorizationResolver {
    /// 决策在 tool result 中使用的稳定标记。
    ///
    /// 工具侧的 `resolveUserResponse` 只认识这些常量；UI 也用同一组常量回传，
    /// 两边共用一份定义，避免文案漂移。
    public static let allowOnceToken = "computer_use.allow_once"
    public static let alwaysAllowToken = "computer_use.always_allow"
    public static let denyToken = "computer_use.deny"

    /// 解析用户决策。
    ///
    /// - Parameter answer: UI 回传的决策标记或文案。
    /// - Returns: 识别出的决策；无法识别时返回 `nil`。
    public static func decision(for answer: String) -> ComputerUseAuthorizationDecision? {
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case allowOnceToken, "允许一次", "仅此一次", "allow once", "allow_once":
            return .allowOnce
        case alwaysAllowToken, "始终允许", "总是允许", "always allow", "always_allow":
            return .alwaysAllow
        case denyToken, "拒绝", "不允许", "deny", "reject", "no":
            return .deny
        default:
            return nil
        }
    }

    /// 决策对应的回传标记。
    public static func token(for decision: ComputerUseAuthorizationDecision) -> String {
        switch decision {
        case .allowOnce: return allowOnceToken
        case .alwaysAllow: return alwaysAllowToken
        case .deny: return denyToken
        }
    }

    /// 拒绝时回传给 agent 的错误文案。
    ///
    /// 必须是明确的「已拒绝 + 不要重试」语义，agent 才能停止该路径而不是
    /// 换个方式再试一次。
    public static func denialMessage(applicationName: String) -> String {
        pluginLocalization
            .string("The user denied Computer Use access to {app}. Do not retry this application in this task.")
            .replacingOccurrences(of: "{app}", with: applicationName)
    }

    /// 允许一次后回传给 agent 的说明。
    ///
    /// 明确告知「仅本次有效」，避免 agent 把一次授权当成长期授权反复使用。
    public static func allowOnceMessage(applicationName: String) -> String {
        pluginLocalization
            .string("Access to {app} is granted for this operation only. Ask again before accessing it again.")
            .replacingOccurrences(of: "{app}", with: applicationName)
    }

    /// 始终允许后回传给 agent 的说明。
    public static func alwaysAllowMessage(applicationName: String) -> String {
        pluginLocalization
            .string("Access to {app} is allowed. You may continue without asking again.")
            .replacingOccurrences(of: "{app}", with: applicationName)
    }
}
