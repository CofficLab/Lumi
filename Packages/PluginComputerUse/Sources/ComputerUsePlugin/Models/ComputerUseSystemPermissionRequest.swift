import Foundation

/// macOS 系统权限类型。
///
/// 只覆盖 Computer Use 实际依赖的两项权限：辅助功能（控制鼠标键盘）与
/// 屏幕录制（截取窗口画面）。二者由 TCC 统一管理，应用自身无法授予，
/// 只能引导用户前往「系统设置 → 隐私与安全性」手动开启。
public enum ComputerUseSystemPermission: String, Codable, Equatable, Sendable, CaseIterable {
    case accessibility
    case screenRecording

    /// 卡片标题中展示的权限名称。
    public var displayName: String {
        switch self {
        case .accessibility: return pluginLocalization.string("Accessibility")
        case .screenRecording: return pluginLocalization.string("Screen Recording")
        }
    }

    /// 「打开系统设置」按钮的文案。
    public var openSystemSettingsTitle: String {
        pluginLocalization.string("Open System Settings")
    }

    /// 缺少该权限时给 LLM 的说明文案。
    ///
    /// 必须是明确的「缺少哪项权限 + 去哪里开启」语义，agent 才能把问题
    /// 归因到系统权限而不是反复重试同一次操作。
    public var missingPermissionMessage: String {
        switch self {
        case .accessibility:
            return pluginLocalization.string(
                "Accessibility permission is required. Open Lumi Settings > Computer Use."
            )
        case .screenRecording:
            return pluginLocalization.string(
                "Screen Recording permission is required. Open Lumi Settings > Computer Use."
            )
        }
    }
}

/// 系统权限提示卡的载荷。
///
/// 由工具在命中系统权限缺失时生成，编码进 tool result 的 `content`；
/// 渲染层从中恢复出卡片需要展示的信息。
///
/// 与 `ComputerUseAuthorizationRequest` 的区别：
/// - 应用级授权（`ComputerUseAuthorizationRequest`）需要挂起回合等待用户决定；
/// - 系统级权限（`ComputerUseSystemPermissionRequest`）用户无法在聊天里决定，
///   只能跳转系统设置，因此工具返回**失败**结果而非挂起。
public struct ComputerUseSystemPermissionRequest: Codable, Equatable, Sendable {
    /// 载荷种类。用于让渲染层只接管自己认识的那一类失败结果。
    public static let kind = "computer_use_system_permission"

    /// 缺失的系统权限。
    public let permission: ComputerUseSystemPermission

    /// 触发本次失败的操作描述（例如「观察 Safari 窗口」）。
    public let operation: String

    public init(permission: ComputerUseSystemPermission, operation: String) {
        self.permission = permission
        self.operation = operation
    }
}
