import Foundation
import LumiCoreKit

/// ToolService 环境桥接器
///
/// 实现 `ToolServiceEnvironment` 协议，将 App 层的 ChatService 和 LumiCore.projectState
/// 连接到 LumiCoreKit 的 ToolService，使其能够通过协议获取 verbosity 和 projectPath。
final class ToolServiceEnvironmentBridge: ToolServiceEnvironment {
    var currentProjectPath: String? {
        LumiCore.projectState?.currentProject?.path
    }
    
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        LumiCore.chatService?.verbosity(for: conversationID) ?? .standard
    }
}
