import LumiKernel
import LumiUI
import SwiftUI

/// Chat 视图占位实现
///
/// 新版 LumiFactory 暂不集成聊天分区，相关能力随 ChatKernelPlugin 迁移后恢复。
struct ChatView: View {
    let kernel: LumiKernel
    let activeID: String
    let isRailOnlyPanel: Bool

    init(
        kernel: LumiKernel,
        activeID: String,
        isRailOnlyPanel: Bool
    ) {
        self.kernel = kernel
        self.activeID = activeID
        self.isRailOnlyPanel = isRailOnlyPanel
    }

    var body: some View {
        AppEmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "Chat 功能将在插件迁移后恢复"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id("\(activeID)-chat")
        .layoutPriority(isRailOnlyPanel ? 1 : 0)
    }

    var toolbarItems: [ChatSectionToolbarItem] {
        kernel.allChatSectionToolbarItems
    }
}