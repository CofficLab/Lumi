import Foundation
import KernelCore
import LumiLoggingKit
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import SwiftUI
import os

/// 「继续」插件：对话异常中断后，在聊天底部提供「继续」按钮。
///
/// ## 解决的问题
///
/// app 崩溃 / 被强杀时，Agent 回合在内存里死了，但消息已经落盘。
/// 重启后用户看到的是「我明明让它干到一半，结果就停在那儿了」，
/// 而没有任何入口能接着干。
///
/// 现有的 `PluginAgentLoopRetry`（自动重试）与 `RetryTurnButton`（消息级重试）
/// 都救不了这种情况：前者只消费进程内的 `AgentLoopEvent.failed`，
/// 后者要求 `agentLoop.state == .failed`，重启后恒为 false。
///
/// ## 判定为什么必须靠持久化
///
/// 用户主动停止与崩溃在**消息层面完全无法区分**：
/// `cancelTurn` 不写终态消息，工具 Job 取消后也因 phase 已终态而跳过补写。
/// 两种情况留下的消息形状一模一样。
///
/// 因此本插件用 `ResumableTurnStore` 在回合开始时写「运行中」、
/// 回合结束时写终态 —— 崩溃时最后一条记录停留在「运行中」，
/// 这才是区分两者的唯一可靠依据。
@MainActor
public final class ConversationResumePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-resume",
        category: "ConversationResumePlugin"
    )

    public let id = "com.coffic.lumi.plugin.conversation-resume"
    public let order = 92
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-resume",
        name: "Conversation Resume",
        description: "Shows a Continue button when a conversation was interrupted unexpectedly.",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    /// 底部提示条的 order。
    ///
    /// 落在 `PluginAskUser`（90）之下、`PluginConversationInput` 的附件预览
    /// （899）与输入框（900）之上 —— 即「消息列表与输入框之间」。
    private static let bannerOrder = 95

    private var coordinator: ResumeCoordinator?
    private var viewModel: ResumeViewModel?

    public init() {}

    // MARK: - 生命周期

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Required providers are unavailable")
            return
        }
        guard let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self) else {
            Self.logger.error("\(Self.t)LifecycleHooksProviding is unavailable")
            return
        }

        let store = ResumableTurnStore(fileURL: Self.storeFileURL())

        let viewModel = ResumeViewModel { [weak self] in
            // 恢复当前选中的会话。协调器内部按会话去重，因此别的会话
            // 正在恢复不会挡住本次操作（#888）。
            await self?.coordinator?.resume()
        }
        self.viewModel = viewModel

        let coordinator = ResumeCoordinator(
            loop: ResumeAgentLoopCapabilityAdapter(agentLoop: agentLoop),
            messages: ResumeMessageCapabilityAdapter(messages: messages),
            conversations: ResumeConversationCapabilityAdapter(conversations: conversations),
            store: store
        ) { [weak viewModel] state in
            viewModel?.apply(state)
            // 让 ChatSection 重新计算 item 的可见性。
            chat.refreshItems()
        }
        self.coordinator = coordinator
        coordinator.start(hooks: ResumeLifecycleHooksCapabilityAdapter(hooks: hooks))

        chat.addItems([
            ChatSectionItem(
                id: "\(id).banner",
                order: Self.bannerOrder,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false,
                isActive: { [weak viewModel] in
                    viewModel?.isResumable == true
                }
            ) { [viewModel] in
                ResumeBannerView(viewModel: viewModel)
            }
        ])

        // 启动后立即判定一次：app 崩溃后重启的场景正是这里要恢复的。
        Task { @MainActor [weak coordinator] in
            await coordinator?.refreshState(for: conversations.selectedConversationID)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        coordinator?.cancel()
        coordinator = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "\(id).banner")
    }

    // MARK: - 存储路径

    /// 回合状态存储文件的位置。
    ///
    /// 放在 `Caches` 而不是 `Application Support`：这是一份**派生状态**——
    /// 它可以从消息历史重建（只是无法区分用户停止与崩溃），丢了只影响
    /// 提示的精确性，不影响用户数据。放 Caches 让系统可以在磁盘紧张时
    /// 回收它。
    private static func storeFileURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent("conversation-resume", isDirectory: true)
            .appendingPathComponent("turns.json")
    }
}
