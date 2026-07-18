import Foundation

/// App 启动期不可恢复的环境/配置错误。
///
/// 用于替换过去启动链路里的 `fatalError`（直接闪退、绕过 CrashedView）和静默吞错。
/// 这类错误一旦发生，App 无法继续正常运行，应由 `WindowMain` 走 `CrashedView`
/// 明确告知用户原因（磁盘问题、权限问题、内核装配异常等），而不是静默降级或闪退。
public enum LumiBootstrapError: LocalizedError {
    /// Application Support 目录无法解析（系统环境异常）。
    case applicationSupportUnavailable

    /// `editorFactory` 收到的 provider 不是 `PluginService`（内核装配错误）。
    case editorProviderCastFailed

    /// `LumiCore.chatService` 不是预期的 `ChatService` 具体类型（内核装配错误）。
    case chatServiceCastFailed(actual: String)

    /// `LumiCore.editorService` 不是预期的 `EditorCoreService` 具体类型（内核装配错误）。
    case editorServiceCastFailed(actual: String)

    public var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "无法定位 Application Support 目录，请检查系统环境与 App 沙盒配置。"
        case .editorProviderCastFailed:
            return "编辑器工厂收到的 provider 不是 PluginService，内核装配异常。"
        case .chatServiceCastFailed(let actual):
            return "LumiCore.chatService 不是 ChatService（实际类型：\(actual)），内核装配异常。"
        case .editorServiceCastFailed(let actual):
            return "LumiCore.editorService 不是 EditorCoreService（实际类型：\(actual)），内核装配异常。"
        }
    }
}
