import Foundation
import os
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderToast
import KitSuperLog
import SwiftUI

/// 会话详细程度控制插件（V1 简洁 / V2 标准 / V3 详细）。
///
/// 复刻自旧版 `Plugins/ConversationVerbosityPlugin`：
/// - 在 Chat 分区工具栏注册详细度 chip（`ChatSectionBarPlacement.toolbarTrailing`）；
/// - 仅把详细度交给消息列表和消息渲染器，V1/V2/V3 不修改发送给 LLM 的提示词。
@MainActor
public final class ConversationVerbosityPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.verbosity", category: "ConversationVerbosity")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.verbosity"
    public let order = 85
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.verbosity",
        name: "Conversation Verbosity",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    private var capabilityAdapter: ConversationVerbosityCapabilityAdapter?
    private var conversationObservation: ConversationManagerObservationBox?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging from kernel")
            return
        }
        let adapter = ConversationVerbosityCapabilityAdapter(conversations: conversations)
        capabilityAdapter = adapter
        conversationObservation?.cancel()
        let observation = ConversationManagerObservationBox(capability: adapter)
        conversationObservation = observation

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 85,
                placement: .toolbarTrailing
            ) {
                VerbosityToolbarView(
                    observation: observation,
                    toast: kernel.resolveProvider((any ToastProviding).self)
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        conversationObservation?.cancel()
        conversationObservation = nil
        capabilityAdapter = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}
