import Foundation
import ProviderConversation

/// 详细度工具栏的唯一数据来源。
///
/// 由插件组装层的 `VerbosityObserver` 在外部会话事件到达时直接更新；
/// View 只读取当前 verbosity 与可用操作。
@MainActor
final class VerbosityViewModel: ObservableObject {
    private let capability: any ConversationVerbosityCapability

    /// 当前展示的详细度（观察事件后刷新）。
    @Published private(set) var selectedVerbosity: ResponseVerbosity
    /// 外部事件刷新计数：会话/详细度变化时 +1，驱动 View 重算派生 UI。
    @Published private(set) var observationRevision = 0

    /// 每个会话最近一次提交的写入任务。新选择必须等上一次写入（内存 + 落盘）
    /// 完全结束再提交，保证写入顺序与点击顺序一致（issue #217）。
    private var selectionTasks: [UUID: Task<Void, Never>] = [:]
    /// 每个会话的选择代次：await 之后写回前比对，过期选择直接丢弃，
    /// 避免旧请求晚到覆盖用户刚选中的新值（仓库异步写回身份校验约定）。
    private var selectionGenerations: [UUID: UInt64] = [:]

    init(capability: any ConversationVerbosityCapability) {
        self.capability = capability
        selectedVerbosity = Self.resolveVerbosity(capability: capability)
    }

    /// Observer 收到事件后调用。
    func refresh() {
        selectedVerbosity = Self.resolveVerbosity(capability: capability)
        observationRevision &+= 1
    }

    func select(_ level: ResponseVerbosity) {
        guard let conversationID = capability.selectedConversationID else {
            capability.setGlobalVerbosity(level)
            return
        }
        let generation = (selectionGenerations[conversationID] ?? 0) &+ 1
        selectionGenerations[conversationID] = generation
        let previous = selectionTasks[conversationID]
        selectionTasks[conversationID] = Task { @MainActor [weak self, capability] in
            // 串行化：等上一次写入完全结束再提交本次，旧异步写入不可能晚于新选择落盘。
            await previous?.value
            // 身份校验：等待期间若已有更新的选择，本次直接放弃，不写任何状态。
            guard let self, self.selectionGenerations[conversationID] == generation else { return }
            await capability.setVerbosityAndWait(level, for: conversationID)
        }
    }

    private static func resolveVerbosity(capability: any ConversationVerbosityCapability) -> ResponseVerbosity {
        if let id = capability.selectedConversationID {
            return capability.verbosity(for: id)
        }
        return capability.globalVerbosity
    }
}
