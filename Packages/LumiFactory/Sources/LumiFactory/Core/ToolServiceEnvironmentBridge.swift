import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import LumiKernel

/// ToolService 运行时环境桥接器（LumiFactory 内部使用）
///
/// 把 `LumiCore.projectComponent` 和 `LumiCore.chatService` 桥接到
/// `ToolServiceEnvironment` 协议，避免 `ToolService` 反向依赖具体 ChatService。
///
/// 由 `LumiCore.bootstrapToolService` 创建并注入到 `ToolService`。
@MainActor
final class ToolServiceEnvironmentBridge: ToolServiceEnvironment {
    private let lumiCore: LumiCoreAccessing

    init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    var currentProjectPath: String? {
        lumiCore.projectComponent.currentProject?.path
    }

    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let chatService = lumiCore.chatService as? any LumiChatServicing else {
            return .standard
        }
        return chatService.verbosity(for: conversationID)
    }
}
