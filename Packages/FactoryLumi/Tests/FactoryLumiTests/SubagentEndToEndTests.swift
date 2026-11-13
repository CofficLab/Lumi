import Foundation
import KernelCore
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// 「父会话调用 run_subagent → 隐藏子会话跑完一个回合 → 父工具结果只拿到结论」
/// 这条主链路的端到端验证（#1313 Task 2）。
///
/// 与 FinderEndToEndTests 同一模式：真实 Kernel、真实工具管理器提交 ToolJob，
/// 只有 LLM 换成脚本化替身——替身在 PluginAgentLoop 启动**之前**注入内核，
/// 因为 AgentLoopManager 在 onBoot 时快照持有 LLMManaging。
@MainActor
@Suite("FactoryLumi · PluginSubagent 端到端", .serialized)
struct SubagentEndToEndTests {

    @Test("同步委托只返回子代理结论与用量摘要，子会话对列表隐藏")
    func syncDelegationReturnsConclusionOnly() async throws {
        let stub = ScriptedLLMManager()
        let task = "Find the answer to life, the universe, and everything."
        let conclusion = "The answer is 42."
        stub.scripts[task] = .text(conclusion)
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))

        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Answer lookup",
            conversationID: parentID
        )

        #expect(result.isError == false)
        #expect(result.content.contains(conclusion))
        #expect(result.content.contains("[subagent]"))

        // 子会话存在、挂在父会话下，但不出现在可见列表里。
        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        let child = try #require(all.first(where: { $0.parentConversationID == parentID }))
        #expect(conversations.conversations.contains(where: { $0.id == child.id }) == false)

        // 子会话自己的历史完整保留任务与结论。
        let childMessages = messages.messages(for: child.id)
        #expect(childMessages.contains(where: { $0.role == .user && $0.content == task }))
        #expect(childMessages.contains(where: { $0.role == .assistant && $0.content.contains(conclusion) }))

        // 父会话历史里没有任何子会话转录——结论只经由工具结果回流。
        #expect(messages.messages(for: parentID).allSatisfy { !$0.content.contains(conclusion) })
    }

    @Test("超长结论被截断，工具结果不会撑爆父上下文")
    func longConclusionIsCapped() async throws {
        let stub = ScriptedLLMManager()
        let task = "Produce a very long report."
        stub.scripts[task] = .text(String(repeating: "A", count: 30_000))
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Long report",
            conversationID: parentID
        )

        #expect(result.isError == false)
        // 实现侧上限 8000 字符，另加用量摘要与截断标记的余量。
        #expect(result.content.count <= 8_200)
        #expect(result.content.contains("[truncated]"))
    }

    @Test("子回合失败时工具抛出执行错误而不是成功字符串")
    func childFailureBecomesToolError() async throws {
        let stub = ScriptedLLMManager()
        let task = "This task will fail."
        stub.scripts[task] = .failure("model exploded")
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Failing task",
            conversationID: parentID
        )

        #expect(result.isError == true)
        #expect(result.content.contains("run_subagent"))
        #expect(result.content.contains("Subagent turn failed"))
    }

    // MARK: - Helpers

    /// 执行一次 run_subagent 调用并等待工具结果。
    ///
    /// 走 `execute`——与 AgentLoop 相同的入口：内部 submit → 等 Job 终态 →
    /// 写结果缓存。裸 `submit` 后轮询 `toolCallResult` 拿不到结果：Job 通道
    /// 不写结果缓存与调用记录库，只有 execute 路径会写。
    private func runSubagent(
        toolManager: any ToolManagerProviding,
        task: String,
        description: String,
        conversationID: UUID,
        timeout: TimeInterval = 30
    ) async throws -> ToolCallResult {
        let callID = UUID().uuidString
        let turnID = UUID()
        let arguments = try JSONSerialization.data(
            withJSONObject: ["task": task, "description": description]
        )
        let call = KitAgentTool.ToolCall(
            id: callID,
            name: "run_subagent",
            arguments: String(decoding: arguments, as: UTF8.self)
        )
        // execute 内部的 Job 等待不响应 Task 取消，结构化任务组超时后仍会
        // 等它跑完才退出；用结果盒轮询，超时即可立刻失败。
        let box = ToolResultBox()
        Task { @MainActor in
            box.result = await toolManager.execute(call, conversationID: conversationID, turnID: turnID)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let result = box.result { return result }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw ToolExecutionError.executionFailed(
            toolName: "run_subagent",
            reason: "tool job did not finish within \(timeout)s"
        )
    }

    /// 造一个注入了脚本化 LLM 的真实内核。
    private func makeKernel(stub: ScriptedLLMManager) throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubagentE2ETests-\(UUID().uuidString)", isDirectory: true)
        let providerFactory = DefaultProviderFactory(dataRootDirectory: root)
        return try KernelFactory.makeKernel(
            providerFactory: providerFactory,
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: [StubLLMInstallerPlugin(stub: stub)]
        )
    }
}

// MARK: - Scripted LLM

/// 跨 Task 传递工具结果的盒子；读写都在 MainActor 上，无需额外同步。
@MainActor
private final class ToolResultBox {
    var result: ToolCallResult?
}

/// 按「最后一条用户消息文本」路由响应的 LLM 替身。
///
/// 子会话 ID 在工具内部才创建，测试无法预知；用任务文本做键可以
/// 精确命中子回合的请求，其余请求（标题生成等）落到默认响应。
@MainActor
private final class ScriptedLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    enum Script {
        case text(String)
        case failure(String)
    }

    var scripts: [String: Script] = [:]
    private(set) var requests: [LLMRequest] = []

    var providerID: String { "stub-provider" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: providerID,
            displayName: "Stub",
            defaultModel: "stub-model",
            models: [LLMModelInfo(id: "stub-model")],
            isLocal: true
        )
    }
    var selectedProviderID: String? { providerID }
    var selectedModel: String? { "stub-model" }
    var providerCount: Int { 1 }

    func allProviders() -> [any SuperLLMProvider] { [self] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == providerID ? self : nil }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    func models(for providerID: String) -> [String] { ["stub-model"] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try respond(to: request)
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let response = try respond(to: request)
        await onChunk(LLMStreamChunk(content: response.content))
        await onChunk(LLMStreamChunk(isDone: true))
        return response
    }

    private func respond(to request: LLMRequest) throws -> LLMResponse {
        requests.append(request)
        let task = request.messages.last(where: { $0.role == .user })?.content ?? ""
        switch scripts[task] ?? .text("ok") {
        case .text(let text):
            return LLMResponse(content: text, model: request.model)
        case .failure(let reason):
            throw ScriptedLLMError(reason: reason)
        }
    }
}

private struct ScriptedLLMError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}

/// 在 PluginAgentLoop（order 8）启动前把内核的 LLMManaging 换成替身。
///
/// 只靠 order 7、**不声明依赖**：内核启动是分批 Kahn——第一轮按 order
/// 启动所有无依赖插件（llm-manager 5 → 本插件 7 → agent-loop 8）。
/// 一旦声明对 llm-manager 的依赖，本插件会被推迟到第二轮，反而晚于
/// agent-loop 的 LLMManaging 快照，替身就装不上了。
@MainActor
private final class StubLLMInstallerPlugin: SuperPlugin {
    let id = "com.coffic.lumi.tests.stub-llm-installer"
    let order = 7
    let metadata = PluginMetadata(
        id: "com.coffic.lumi.tests.stub-llm-installer",
        name: "Stub LLM Installer",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private let stub: ScriptedLLMManager

    init(stub: ScriptedLLMManager) {
        self.stub = stub
    }

    func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any LLMManaging).self)
        try kernel.registerProvider((any LLMManaging).self, stub)
    }
}