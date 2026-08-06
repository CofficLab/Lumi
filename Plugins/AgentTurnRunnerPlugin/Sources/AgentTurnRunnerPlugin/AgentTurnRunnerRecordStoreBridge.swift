import Foundation

/// 运行时桥,用于在 AgentTurnRunner(发送请求处)、设置视图、OnReady 钩子之间
/// 共享 store 实例与数据目录。
///
/// 模式与 ConversationManagerRuntimeBridge 一致:OnReady 阶段创建 store 并写入,
/// 其余位置通过 `shared` 读取。
///
/// `AgentTurnRecordStore` 同时管理 LLM 请求调试数据和 turn 级元数据。
@MainActor
final class AgentTurnRunnerRecordStoreBridge: @unchecked Sendable {
    static let shared = AgentTurnRunnerRecordStoreBridge()

    var store: AgentTurnRecordStore?
    var dataDirectory: URL?

    private init() {}
}
