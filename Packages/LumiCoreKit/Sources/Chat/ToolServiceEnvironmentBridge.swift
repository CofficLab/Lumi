import Foundation

/// ToolService 运行时环境桥接器（CoreKit 内部使用）
///
/// 把 `LumiCore.projectState` 和 `LumiCore.chatService` 桥接到
/// `ToolServiceEnvironment` 协议，避免 `ToolService` 反向依赖具体 ChatService。
///
/// 由 `LumiCore.bootstrapToolContributions` 在工具编排完成后注入到 `ToolService`。
@MainActor
final class ToolServiceEnvironmentBridge: ToolServiceEnvironment {
    var currentProjectPath: String? {
        LumiCore.projectState?.currentProject?.path
    }

    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        LumiCore.chatService?.verbosity(for: conversationID) ?? .standard
    }
}