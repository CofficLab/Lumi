import Foundation
import LumiKernel

/// ConversationList 工具运行时桥接
///
/// 用于在 Agent Tools 中访问 v5 的 `ConversationManaging` 服务。
/// Tools 通过这个桥接从主线程读 / 写 conversations 数据,
/// 避免 tools 直接持有 `kernel.conversations` 引用。
@MainActor
enum ConversationListToolRuntimeBridge {
    nonisolated(unsafe) static var conversations: (any ConversationManaging)?

    /// 当前项目路径(可选)。Tools 在创建新对话时如果需要 projectPath,使用该值。
    /// 后续等 ConversationManaging 协议扩展后再做细粒度控制。
    nonisolated(unsafe) static var currentProjectPath: String?
}
