import AgentToolKit
import Foundation
import LLMKit

/// 插件注册期运行时能力。
///
/// App 层只构造这些通用能力，不按具体插件名配置 bridge。
/// 具体插件在 ``SuperPlugin/configureRuntime(context:)`` 中按需读取并绑定自己的运行时依赖。
@MainActor
public struct PluginRuntimeContext {
    /// 按插件 UI 上下文解析当前窗口对应的编辑器服务。
    ///
    /// LumiCoreKit 不直接依赖 EditorService，因此这里保持类型擦除；
    /// 需要完整 EditorService API 的编辑器插件可在自己的包内强转。
    public let editorServiceProvider: @MainActor (PluginContext) -> AnyObject?

    /// 打开文件能力。
    public let openFile: @MainActor (URL, String?, PluginContext) async -> Void

    /// 按文件路径打开文件能力。
    public let openFilePath: @MainActor (String, UUID?) -> Void

    /// 当前项目路径能力。
    public let currentProjectPath: @MainActor (PluginContext) -> String?

    /// 当前活跃窗口 ID。
    public let activeWindowId: @MainActor () -> UUID?

    /// 当前编辑器主题 ID。
    public let editorThemeId: @MainActor () -> String

    /// 是否显示助手消息头部。
    public let showsAssistantHeader: @MainActor () -> Bool

    /// 注册编辑器文本输入安装器。
    ///
    /// LumiCoreKit 不直接依赖 EditorService/CodeEditTextView，因此使用类型擦除。
    /// 具体编辑器插件可在自己的包内强转为需要的宿主类型。
    public let registerEditorTextInputInstaller: @MainActor (@escaping @MainActor (AnyObject, AnyObject) -> Void) -> Void

    /// 应用编辑器字体名称。
    public let applyEditorFontName: @MainActor (String?, PluginContext) -> Void

    /// 插件数据库根目录。
    public let databaseDirectory: @Sendable () -> URL

    /// 将用户消息入队。
    public let enqueueUserMessage: @MainActor (ChatMessage, TurnFinishedContext) -> Void

    /// 将文本添加到当前对话。
    public let addToChat: @MainActor (String, PluginContext) -> Void

    /// 选择对话。
    public let selectConversation: @MainActor (UUID, PluginContext) -> Void

    /// 注册空闲时间快照提供器。
    public let registerIdleTimeSnapshotProvider: @MainActor (@escaping IdleTimeSnapshotProviderClosure) -> Void

    /// 恢复等待用户回答的工具调用。
    ///
    /// 当 `ask_user` 等工具暂停了 Agent 循环后，用户在 UI 上做出选择，
    /// 渲染器通过此回调将用户答案写回 `ToolCall.result` 并恢复 `AgentTurnService.run()`。
    ///
    /// - Parameters:
    ///   - conversationId: 会话 ID（UUID 字符串）
    ///   - toolCallId: 工具调用 ID
    ///   - answer: 用户的回答
    public let resumeToolCall: @MainActor (String, String, String) -> Void

    /// Agent 会话持久化服务（消息与 Turn 阶段）。
    ///
    /// 为 `nil` 时表示当前环境未注入（如测试或预览场景）。
    public let agentConversationStore: (any AgentConversationStore)?

    /// 保存消息到数据库。
    public let saveMessage: @MainActor (ChatMessage, UUID) -> Void

    /// 更新已存在的消息（同 ID 覆盖）。
    public let updateMessage: @MainActor (ChatMessage, UUID) -> Void

    /// 加载会话全部消息。
    public let loadMessages: @MainActor (UUID) -> [ChatMessage]

    /// 读取 Agent Turn 阶段。
    public let loadTurnPhase: @MainActor (UUID) -> AgentTurnPhase

    /// 设置 Agent Turn 阶段。
    public let setTurnPhase: @MainActor (AgentTurnPhase, UUID) -> Void

    /// 尝试获取会话处理锁。
    public let tryAcquireConversationLock: @MainActor (UUID) -> Bool

    /// 释放会话处理锁。
    public let releaseConversationLock: @MainActor (UUID) -> Void

    /// 会话是否已被用户取消。
    public let isConversationCancelled: @MainActor (UUID) -> Bool

    /// 标记会话已取消。
    public let markConversationCancelled: @MainActor (UUID) -> Void

    /// 清除会话取消标记。
    public let clearConversationCancelled: @MainActor (UUID) -> Void

    /// 裁剪并展开消息供 LLM 使用。
    public let prepareMessagesForLLM: @MainActor (UUID, [ChatMessage]) -> [ChatMessage]

    /// LLM 发送服务（解析配置、调用供应商、流式回调）。
    ///
    /// 为 `nil` 时表示当前环境未注入（如测试或预览场景）。
    public let llmSendService: (any LLMSendService)?

    /// 消费并返回首轮临时 system prompts。
    public let consumeTransientSystemPrompts: @MainActor (UUID) -> [String]

    /// 若需工具权限则暂停执行；返回 true 表示已暂停（用户在消息列表内联授权）。
    public let presentToolPermissionIfNeeded: @MainActor (ChatMessage, UUID) async -> Bool

    /// 用户在消息列表中响应工具授权（同意/拒绝）。
    public let respondToToolPermission: @MainActor (UUID, UUID, String, Bool) async -> Void

    /// 评估工具调用的风险等级（供内联授权 UI 展示）。
    public let evaluateToolPermissionRisk: @MainActor (String, String) -> CommandRiskLevel

    /// 执行助手消息中的工具调用并写库。
    public let executeToolCalls: @MainActor (ChatMessage, UUID) async -> ToolExecutionSummary

    /// Turn 正常/异常收尾（队列、状态 UI、TurnFinished 管线）。
    public let finishAgentTurn: @MainActor (UUID, TurnEndReason) -> Void

    /// 设置会话发送状态文案。
    public let setConversationStatus: @MainActor (UUID, String) -> Void

    /// 取出最早 pending user 消息并标记 processing。
    public let dequeueNextPendingMessage: @MainActor (UUID) -> ChatMessage?

    /// 运行 SendPipeline 发送前中间件，返回临时 system prompts。
    public let runSendPreparePipeline: @MainActor (UUID, ChatMessage) async -> [String]

    /// 存储 SendPipeline 产出的临时 system prompts。
    public let storeTransientSystemPrompts: @MainActor ([String], UUID) -> Void

    /// 查询 pending 队列消息。
    public let pendingMessages: @MainActor (UUID) -> [ChatMessage]

    /// 移除 pending 消息。
    public let removePendingMessage: @MainActor (UUID, UUID) -> Bool

    /// 按 ID 查找 LLM 供应商类型。
    public let providerTypeProvider: @MainActor (String) -> (any SuperLLMProvider.Type)?

    /// 当前全局选中的供应商 ID。
    public let selectedProviderIdProvider: @MainActor () -> String

    /// 按 ID 查找供应商信息。
    public let providerInfoProvider: @MainActor (String) -> LLMProviderInfo?

    /// 读取会话标题。
    public let fetchConversationTitle: @MainActor (UUID) -> String?

    /// 更新会话标题。
    public let updateConversationTitle: @MainActor (UUID, String) -> Bool

    public init(
        editorServiceProvider: @escaping @MainActor (PluginContext) -> AnyObject? = { _ in nil },
        openFile: @escaping @MainActor (URL, String?, PluginContext) async -> Void = { _, _, _ in },
        openFilePath: @escaping @MainActor (String, UUID?) -> Void = { _, _ in },
        currentProjectPath: @escaping @MainActor (PluginContext) -> String? = { context in
            context.currentProjectPath.isEmpty ? nil : context.currentProjectPath
        },
        activeWindowId: @escaping @MainActor () -> UUID? = { nil },
        editorThemeId: @escaping @MainActor () -> String = { "xcode-dark" },
        showsAssistantHeader: @escaping @MainActor () -> Bool = { false },
        registerEditorTextInputInstaller: @escaping @MainActor (@escaping @MainActor (AnyObject, AnyObject) -> Void) -> Void = { _ in },
        applyEditorFontName: @escaping @MainActor (String?, PluginContext) -> Void = { _, _ in },
        databaseDirectory: @escaping @Sendable () -> URL = {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
            return appSupport.appendingPathComponent(bundleID, isDirectory: true)
                .appendingPathComponent("db", isDirectory: true)
        },
        enqueueUserMessage: @escaping @MainActor (ChatMessage, TurnFinishedContext) -> Void = { _, _ in },
        addToChat: @escaping @MainActor (String, PluginContext) -> Void = { _, _ in },
        selectConversation: @escaping @MainActor (UUID, PluginContext) -> Void = { _, _ in },
        registerIdleTimeSnapshotProvider: @escaping @MainActor (@escaping IdleTimeSnapshotProviderClosure) -> Void = { _ in },
        resumeToolCall: @escaping @MainActor (String, String, String) -> Void = { _, _, _ in },
        agentConversationStore: (any AgentConversationStore)? = nil,
        saveMessage: @escaping @MainActor (ChatMessage, UUID) -> Void = { _, _ in },
        updateMessage: @escaping @MainActor (ChatMessage, UUID) -> Void = { _, _ in },
        loadMessages: @escaping @MainActor (UUID) -> [ChatMessage] = { _ in [] },
        loadTurnPhase: @escaping @MainActor (UUID) -> AgentTurnPhase = { _ in .idle },
        setTurnPhase: @escaping @MainActor (AgentTurnPhase, UUID) -> Void = { _, _ in },
        tryAcquireConversationLock: @escaping @MainActor (UUID) -> Bool = { _ in false },
        releaseConversationLock: @escaping @MainActor (UUID) -> Void = { _ in },
        isConversationCancelled: @escaping @MainActor (UUID) -> Bool = { _ in false },
        markConversationCancelled: @escaping @MainActor (UUID) -> Void = { _ in },
        clearConversationCancelled: @escaping @MainActor (UUID) -> Void = { _ in },
        prepareMessagesForLLM: @escaping @MainActor (UUID, [ChatMessage]) -> [ChatMessage] = { _, messages in messages },
        llmSendService: (any LLMSendService)? = nil,
        consumeTransientSystemPrompts: @escaping @MainActor (UUID) -> [String] = { _ in [] },
        presentToolPermissionIfNeeded: @escaping @MainActor (ChatMessage, UUID) async -> Bool = { _, _ in false },
        respondToToolPermission: @escaping @MainActor (UUID, UUID, String, Bool) async -> Void = { _, _, _, _ in },
        evaluateToolPermissionRisk: @escaping @MainActor (String, String) -> CommandRiskLevel = { _, _ in .high },
        executeToolCalls: @escaping @MainActor (ChatMessage, UUID) async -> ToolExecutionSummary = { _, _ in ToolExecutionSummary() },
        finishAgentTurn: @escaping @MainActor (UUID, TurnEndReason) -> Void = { _, _ in },
        setConversationStatus: @escaping @MainActor (UUID, String) -> Void = { _, _ in },

        dequeueNextPendingMessage: @escaping @MainActor (UUID) -> ChatMessage? = { _ in nil },
        runSendPreparePipeline: @escaping @MainActor (UUID, ChatMessage) async -> [String] = { _, _ in [] },
        storeTransientSystemPrompts: @escaping @MainActor ([String], UUID) -> Void = { _, _ in },
        pendingMessages: @escaping @MainActor (UUID) -> [ChatMessage] = { _ in [] },
        removePendingMessage: @escaping @MainActor (UUID, UUID) -> Bool = { _, _ in false },
        providerTypeProvider: @escaping @MainActor (String) -> (any SuperLLMProvider.Type)? = { _ in nil },
        selectedProviderIdProvider: @escaping @MainActor () -> String = { "" },
        providerInfoProvider: @escaping @MainActor (String) -> LLMProviderInfo? = { _ in nil },
        fetchConversationTitle: @escaping @MainActor (UUID) -> String? = { _ in nil },
        updateConversationTitle: @escaping @MainActor (UUID, String) -> Bool = { _, _ in false },
    ) {
        self.editorServiceProvider = editorServiceProvider
        self.openFile = openFile
        self.openFilePath = openFilePath
        self.currentProjectPath = currentProjectPath
        self.activeWindowId = activeWindowId
        self.editorThemeId = editorThemeId
        self.showsAssistantHeader = showsAssistantHeader
        self.registerEditorTextInputInstaller = registerEditorTextInputInstaller
        self.applyEditorFontName = applyEditorFontName
        self.databaseDirectory = databaseDirectory
        self.enqueueUserMessage = enqueueUserMessage
        self.addToChat = addToChat
        self.selectConversation = selectConversation
        self.registerIdleTimeSnapshotProvider = registerIdleTimeSnapshotProvider
        self.resumeToolCall = resumeToolCall
        self.agentConversationStore = agentConversationStore
        self.saveMessage = saveMessage
        self.updateMessage = updateMessage
        self.loadMessages = loadMessages
        self.loadTurnPhase = loadTurnPhase
        self.setTurnPhase = setTurnPhase
        self.tryAcquireConversationLock = tryAcquireConversationLock
        self.releaseConversationLock = releaseConversationLock
        self.isConversationCancelled = isConversationCancelled
        self.markConversationCancelled = markConversationCancelled
        self.clearConversationCancelled = clearConversationCancelled
        self.prepareMessagesForLLM = prepareMessagesForLLM
        self.llmSendService = llmSendService
        self.consumeTransientSystemPrompts = consumeTransientSystemPrompts
        self.presentToolPermissionIfNeeded = presentToolPermissionIfNeeded
        self.respondToToolPermission = respondToToolPermission
        self.evaluateToolPermissionRisk = evaluateToolPermissionRisk
        self.executeToolCalls = executeToolCalls
        self.finishAgentTurn = finishAgentTurn
        self.setConversationStatus = setConversationStatus

        self.dequeueNextPendingMessage = dequeueNextPendingMessage
        self.runSendPreparePipeline = runSendPreparePipeline
        self.storeTransientSystemPrompts = storeTransientSystemPrompts
        self.pendingMessages = pendingMessages
        self.removePendingMessage = removePendingMessage
        self.providerTypeProvider = providerTypeProvider
        self.selectedProviderIdProvider = selectedProviderIdProvider
        self.providerInfoProvider = providerInfoProvider
        self.fetchConversationTitle = fetchConversationTitle
        self.updateConversationTitle = updateConversationTitle
    }
}
