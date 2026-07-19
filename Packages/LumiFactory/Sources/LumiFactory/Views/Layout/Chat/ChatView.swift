import LumiCoreKit
import LumiUI
import SwiftUI

/// Chat 视图占位实现
///
/// 新版 LumiFactory 暂不集成聊天分区，相关能力随 ChatKernelPlugin 迁移后恢复。
struct ChatView: View {
    let chatSection: LumiChatSectionLayout
    let activeID: String
    let isRailOnlyPanel: Bool

    init(
        layoutState: LayoutState? = nil,
        pluginService: Any? = nil,
        lumiCore: (any LumiCoreAccessing)? = nil,
        chatSectionCoordinator: ChatSectionCoordinator? = nil,
        chatSection: LumiChatSectionLayout,
        activeID: String,
        isRailOnlyPanel: Bool
    ) {
        self.chatSection = chatSection
        self.activeID = activeID
        self.isRailOnlyPanel = isRailOnlyPanel
    }

    var body: some View {
        Group {
            if chatSection.isVisible {
                AppEmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "Chat 功能将在插件迁移后恢复"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("\(activeID)-\(chatSection.persistenceKeySuffix)")
                .layoutPriority(isRailOnlyPanel ? 1 : 0)
            }
        }
    }

    var toolbarItems: [LumiChatSectionToolbarItem] {
        []
    }
}
