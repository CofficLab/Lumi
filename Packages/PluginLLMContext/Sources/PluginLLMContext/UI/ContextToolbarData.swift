import Foundation
import ProviderLLMContext
import ProviderMessage

/// ContextToolbar 的数据快照与刷新编排（#1257）。
///
/// 按钮上常显的数据（用量、压缩事件）无论弹窗开关都要刷新；
/// 仅弹窗展示的数据（趋势曲线、幕后调用用量）在弹窗关闭时跳过，
/// 打开弹窗时再补拉一次。闭窗时的每轮去抖刷新因此少做两次全量
/// 快照读取与整史构建（趋势曲线的排序/遍历/估算都在主线程）。
@Observable
@MainActor
final class ContextToolbarData {
    private let provider: LLMContextProvider
    private let messages: any MessageManaging

    private(set) var selectedConversationID: UUID?
    private(set) var usage: ContextWindowUsageSnapshot?
    private(set) var history: ContextUsageHistory = .empty
    private(set) var events: [Message] = []
    private(set) var auxiliaryEntries: [LLMAuxiliaryUsageEntry] = []

    init(provider: LLMContextProvider, messages: any MessageManaging) {
        self.provider = provider
        self.messages = messages
    }

    func setSelectedConversationID(_ id: UUID?) {
        selectedConversationID = id
    }

    /// 一轮去抖刷新的入口：闭窗只取按钮数据，开窗取全部。
    func refresh(isPopoverPresented: Bool, for conversationID: UUID?) async {
        await refreshVisible(for: conversationID)
        if isPopoverPresented {
            await refreshPopoverOnly(for: conversationID)
        }
    }

    /// 按钮常显数据：用量 + 压缩事件。
    func refreshVisible(for conversationID: UUID?) async {
        await refreshUsage(for: conversationID)
        await refreshEvents(for: conversationID)
    }

    /// 仅弹窗展示的数据：趋势曲线 + 幕后调用用量。打开弹窗时调用。
    func refreshPopoverOnly(for conversationID: UUID?) async {
        await refreshHistory(for: conversationID)
        await refreshAuxiliaryUsage(for: conversationID)
    }

    private func refreshUsage(for conversationID: UUID?) async {
        let snapshot = await provider.contextWindowUsage(for: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        usage = snapshot
    }

    private func refreshHistory(for conversationID: UUID?) async {
        guard let conversationID else {
            history = .empty
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        history = ContextUsageHistory.build(from: snapshot)
    }

    private func refreshEvents(for conversationID: UUID?) async {
        guard let conversationID else {
            events = []
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        events = snapshot
            .filter(MessageTimelineEvent.isActualContextCompaction)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id > rhs.id }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private func refreshAuxiliaryUsage(for conversationID: UUID?) async {
        guard let conversationID else {
            auxiliaryEntries = []
            return
        }
        let entries = await provider.auxiliaryUsageEntries(for: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        auxiliaryEntries = entries
    }
}
