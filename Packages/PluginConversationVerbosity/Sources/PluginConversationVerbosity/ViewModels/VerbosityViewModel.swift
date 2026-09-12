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
        if let conversationID = capability.selectedConversationID {
            Task { @MainActor in
                await capability.setVerbosityAndWait(level, for: conversationID)
            }
        } else {
            capability.setGlobalVerbosity(level)
        }
    }

    private static func resolveVerbosity(capability: any ConversationVerbosityCapability) -> ResponseVerbosity {
        if let id = capability.selectedConversationID {
            return capability.verbosity(for: id)
        }
        return capability.globalVerbosity
    }
}
