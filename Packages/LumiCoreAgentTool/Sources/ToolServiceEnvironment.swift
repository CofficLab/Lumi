import Foundation
import LumiCoreMessage

/// ToolService 的运行环境协议
///
/// 通过依赖注入解耦 ToolService 对 LumiCore 全局单件和 ChatService 的具体类型依赖，
/// 使 ToolService 可以在 LumiCoreKit 内部独立实现，无需导入 LumiChatKit 或访问全局状态。
///
/// 实现者通常在 App 层（如 RootContainer）提供，桥接实际的 ChatService 和 ProjectState。
@MainActor
public protocol ToolServiceEnvironment: AnyObject {
    /// 获取会话的详细程度
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity

    /// 获取当前项目路径
    var currentProjectPath: String? { get }
}
