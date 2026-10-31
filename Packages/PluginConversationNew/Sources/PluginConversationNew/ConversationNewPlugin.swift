import os
import KernelCore
import KitAgentTool
import LumiLoggingKit
import ProviderChatSection
import ProviderConversation
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolbar
import ProviderToolManager
import SwiftUI

/// 新建会话插件。
///
/// 提供两条互补的「开新对话」入口：
/// - 工具栏「新建会话」按钮：用户主动开一个空白对话；
/// - Agent 工具 `create_new_conversation`：LLM 在发现与当前话题**实质不同**的新任务时，
///   创建一个顶层对话并在消息列表留下建议卡片；用户点击卡片按钮后切到新对话、
///   自动发送首条消息并自动开始回合。
///
/// 回合内只创建对话、不切换选中态；切换与发送全部发生在回合之外（见 README）。
@MainActor
public final class ConversationNewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-new", category: "ConversationNew")

    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-new",
        name: "Conversation New",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 对齐旧版 ConversationNewPlugin 的元数据：
    /// - name "New Chat Button"（旧版 LumiPluginLocalization）
    /// - policy .alwaysOn → .required（不可禁用）
    /// - stage .beta → .preview

    private var toolbarObserver: NewChatToolbarObserver?
    private var capability: NewChatCapabilityAdapter?
    private var startingCapability: NewChatStartingAdapter?
    private var viewModel: NewChatViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding, ConversationManaging or ChatSectionProviding from kernel")
            return
        }

        // 组装层：创建 Capability + ViewModel，注入视图。
        let capability = NewChatCapabilityAdapter(conversations: conversations)
        let viewModel = NewChatViewModel(capability: capability)
        self.capability = capability
        self.viewModel = viewModel

        registerSuggestionFlow(kernel: kernel, capability: capability)

        let toolbarItemID = "\(id).new-chat"
        toolbarObserver = NewChatToolbarObserver(
            toolbar: toolbar,
            conversations: conversations,
            chat: chat,
            itemID: toolbarItemID
        ) {
            ToolbarItem(
                id: toolbarItemID,
                title: pluginLocalization.string("New Chat"),
                placement: .trailing,
                category: .chat,
                order: 30
            ) {
                NewChatButton(viewModel: viewModel)
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .unregister(id: NewConversationRowRenderer.id)
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: CreateNewConversationTool.toolName)

        toolbarObserver?.cancel()
        toolbarObserver = nil
        viewModel = nil
        startingCapability = nil
        capability = nil
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).new-chat"])
    }

    // MARK: - LLM 建议新话题

    /// 注册 `create_new_conversation` 工具及其结果渲染器。
    ///
    /// 与工具栏入口相互独立：即使 `ToolManagerProviding` 缺失，工具栏按钮
    /// 仍应正常工作，因此这里不做提前 return。
    private func registerSuggestionFlow(
        kernel: KernelCoreContainer,
        capability: NewChatCapabilityAdapter
    ) {
        // 卡片点击时才需要发送能力；缺失时仍注册工具与渲染器（按钮保持禁用）。
        let startingCapability = kernel
            .resolveProvider((any MessageSendingProviding).self)
            .map(NewChatStartingAdapter.init(sender:))
        if startingCapability == nil {
            Self.logger.warning("\(Self.t)MessageSendingProviding unavailable; the suggestion card button will be disabled")
        }
        self.startingCapability = startingCapability

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding; new conversation tool was not registered")
            return
        }
        toolManager.add(
            CreateNewConversationTool(conversations: capability),
            pluginID: id
        )

        if let rendering = kernel.resolveProvider((any ToolCallRenderingProviding).self) {
            rendering.register(NewConversationRowRenderer(
                conversations: capability,
                sender: startingCapability
            ))
        } else {
            Self.logger.error("\(Self.t)Failed to resolve ToolCallRenderingProviding; suggestions will fall back to the default tool card")
        }
    }
}
