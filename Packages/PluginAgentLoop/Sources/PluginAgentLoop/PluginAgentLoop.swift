import Foundation
import KernelCore
import KitLLM
import LumiLoggingKit
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// AgentLoop 插件
///
/// 使用自定义的 AgentLoopProvider 替换默认的 DefaultAgentLoopProvider。
/// AgentLoopProvider 负责 LLM step、回合状态机和结果回写；工具调用通过事件
/// 交给 PluginToolManager，授权 UI 通过 AgentLoop 的恢复接口继续回合。
///
/// 执行顺序：order = 8
/// - 在 DefaultProviderFactory 注册默认实现之后执行
/// - 使用 unregisterProvider + registerProvider 模式替换默认实现
@MainActor
public final class PluginAgentLoop: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    public let id = "com.coffic.lumi.plugin.agent-loop"
    public let order = 8
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.agent-loop",
        name: "Plugin Agent Loop",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private var messageObserver: MessageObserver?
    private var toolManagerObserver: ToolManagerObserver?
    private var toolJobObserver: ToolJobObserver?
    /// 本插件创建的具体实现；UI 测试夹具需要写 `runtimes`，故保留强引用。
    private var manager: AgentLoopManager?
    /// UI 测试夹具等待会话加载完成的观察句柄（仅 DEBUG 使用）。
    private var uiTestingSeedHandle: (any ConversationObserverHandle)?
    /// UI 测试夹具旁听回合启动的观察句柄（仅 DEBUG 使用）。
    private var uiTestingTurnObserver: (any AgentLoopObserverHandle)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 获取必需依赖
        guard let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.emoji)MessageManaging not found, skip AgentLoop replacement")
            return
        }
        guard let llmManager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.emoji)LLMManaging not found, skip AgentLoop replacement")
            return
        }
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.emoji)ToolManagerProviding not found, skip AgentLoop replacement")
            return
        }
        guard let streaming = kernel.resolveProvider((any MessageStreamingProviding).self) else {
            Self.logger.error("\(Self.emoji)MessageStreamingProviding not found, skip AgentLoop replacement")
            return
        }
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.emoji)ConversationManaging not found, skip AgentLoop replacement")
            return
        }
        guard let contextProvider = kernel.resolveProvider((any LLMContextProviding).self) else {
            Self.logger.error("\(Self.emoji)LLMContextProviding not found, skip AgentLoop replacement")
            return
        }

        // 2. 创建自定义实现
        let agentLoop = AgentLoopManager(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations,
            contextProvider: contextProvider
        )
        self.manager = agentLoop
        toolJobObserver = ToolJobObserver(toolManager: toolManager) { [weak agentLoop] event in
            agentLoop?.handleToolJobEvent(event)
        }
        agentLoop.setLifecycleHooks(kernel.resolveProvider((any LifecycleHooksProviding).self))

        // 3. 注销默认的 AgentLoopProviding
        kernel.unregisterProvider((any AgentLoopProviding).self)

        // 4. 注册自定义实现；消息发送器由 MessageSenderPlugin 在此之后装配。
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        messageObserver?.cancel()
        messageObserver = nil
        toolManagerObserver?.cancel()
        toolManagerObserver = nil
        toolJobObserver?.cancel()
        toolJobObserver = nil
        uiTestingTurnObserver?.cancel()
        uiTestingTurnObserver = nil
        manager = nil
        // 插件卸载时，内核会自动按归属移除 Provider
    }

    /// 所有 Provider 完成 Boot 后，监听用户消息并启动 Agent 回合。
    ///
    /// MessageSender 只负责把 user message 写入 MessageManaging；回合的启动
    /// 由本插件通过消息事件完成，避免发送器和 AgentLoop 之间的直接调用。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let messages = kernel.resolveProvider((any MessageManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.emoji)MessageManaging or AgentLoopProviding not found, skip message subscription")
            return
        }

        messageObserver = MessageObserver(messages: messages, agentLoop: agentLoop)
        toolManagerObserver = ToolManagerObserver(toolManager: toolManager, agentLoop: agentLoop)

        #if DEBUG
        if let manager {
            seedErrorRetryUITestingFixtureIfNeeded(
                agentLoop: manager,
                messages: messages,
                kernel: kernel
            )
        }
        #endif
    }

    /// UI 测试夹具（仅 DEBUG）：为「重试该回合」按钮造一个确定性失败回合。
    ///
    /// 只在 `--lumi-ui-testing-error-retry` 启动参数下生效；见
    /// `ErrorRetryUITestingSupport`。
    ///
    /// - Note: 必须等会话列表加载完成后再植入。`loadConversations()` 会整体替换
    ///   会话列表并在未选中时清空选中态；若过早植入，夹具会话会被这次加载覆盖，
    ///   表现为「侧栏里看不到测试会话、消息区空白」。
    private func seedErrorRetryUITestingFixtureIfNeeded(
        agentLoop: AgentLoopManager,
        messages: any MessageManaging,
        kernel: KernelCoreContainer
    ) {
        guard ErrorRetryUITestingSupport.isEnabled else { return }
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.emoji)UI 测试夹具缺少 ConversationManaging")
            return
        }

        let seed: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            guard let conversationID = try? conversations.createConversation(
                title: ErrorRetryUITestingSupport.conversationTitle,
                projectPath: nil,
                providerID: nil,
                modelName: nil
            ) else {
                Self.logger.error("\(Self.emoji)UI 测试夹具创建会话失败")
                return
            }
            ErrorRetryUITestingSupport.seedFailedTurn(
                in: agentLoop,
                conversationID: conversationID,
                messages: messages
            )
            self.uiTestingTurnObserver = ErrorRetryUITestingSupport.observeTurnStarts(
                manager: agentLoop,
                messages: messages,
                conversationID: conversationID
            )
            // createConversation 已自动选中，这里再显式选一次，确保消息区切到夹具会话。
            conversations.selectConversation(id: conversationID)
            // header 操作按钮只在 detailed 级别常驻显示，直接设好省去 UI 交互。
            conversations.setVerbosity(ErrorRetryUITestingSupport.verbosity, for: conversationID)
            Self.logger.info("\(Self.emoji)UI 测试夹具已植入失败回合 conversation=\(conversationID.uuidString.prefix(8))")
        }

        if conversations.isLoadingConversations {
            // 等待加载完成；句柄存到属性上以便重复 cancel 语义清晰。
            let box = ObserverHandleBox()
            let handle = conversations.addConversationObserver { event in
                guard case .listChanged = event else { return }
                box.handle?.cancel()
                box.handle = nil
                self.uiTestingSeedHandle = nil
                seed()
            }
            box.handle = handle
            uiTestingSeedHandle = handle
        } else {
            seed()
        }
    }
}

/// 让观察者闭包能引用到自己的注销句柄（自取消的一次性观察）。
private final class ObserverHandleBox {
    var handle: (any ConversationObserverHandle)?
}
