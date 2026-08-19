import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessageStreaming
import ProviderToolManager
import SuperLogKit

/// 由 `AgentLoopProvider` 注入/更新的回合运行依赖。
///
/// Manager 只依赖这一组 service，不反向持有 Provider（保持门面 → Manager 方向）。
/// 新增依赖（如未来的消息准备器、工具执行器等）在此扩展字段即可。
struct AgentLoopDependencies {
    var responder: AgentLoopResponder?
    var llmManager: (any LLMManaging)?
    var toolManager: (any ToolManagerProviding)?
    var streaming: (any MessageStreamingProviding)?
    var conversations: (any ConversationManaging)?
    var eventHandler: AgentLoopEventHandler?
}
