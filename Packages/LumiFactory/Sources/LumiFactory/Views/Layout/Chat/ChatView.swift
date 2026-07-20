import LumiCoreLayout
import LumiKernel
import LumiUI
import SwiftUI

/// 整合 Chat 视图相关代码
///
/// 封装了 ChatSection 的可见性判断、items 获取等逻辑。
/// 新版基于 LumiKernel，插件通过 `kernel.registerChatSectionItem` / `registerChatSectionToolbarItem` /
/// `registerChatSectionToolbarBarItem` / `registerChatSectionHeaderItem` 注册贡献，
/// 这里直接从 `kernel.allChatSectionItems` 等聚合器拉取并按 placement 过滤。
struct ChatView: View {
    let layoutState: LayoutStateInfo
    let kernel: LumiKernel
    let chatSection: LumiChatSectionLayout
    let activeID: String
    let isRailOnlyPanel: Bool

    init(
        layoutState: LayoutStateInfo,
        kernel: LumiKernel,
        chatSection: LumiChatSectionLayout,
        activeID: String,
        isRailOnlyPanel: Bool
    ) {
        self.layoutState = layoutState
        self.kernel = kernel
        self.chatSection = chatSection
        self.activeID = activeID
        self.isRailOnlyPanel = isRailOnlyPanel
    }

    /// 是否在当前视口里展示 Chat 区域。
    ///
    /// 两个条件都满足才显示：
    /// 1. `chatSection` 布局档位非 `.none`（用户/视图容器启用了 Chat 区域）
    /// 2. `layoutState.chatSectionVisible`（用户没手动隐藏）
    private var shouldShowChatSection: Bool {
        chatSection.isVisible && layoutState.chatSectionVisible
    }

    private var chatSectionItems: [ChatSectionItem] {
        kernel.allChatSectionItems
    }

    private var chatSectionToolbarItems: [ChatSectionToolbarItem] {
        shouldShowChatSection ? kernel.allChatSectionToolbarItems : []
    }

    private var chatSectionToolbarBarItems: [ChatSectionToolbarBarItem] {
        shouldShowChatSection ? kernel.allChatSectionToolbarBarItems : []
    }

    private var chatSectionHeaderItems: [ChatSectionHeaderItem] {
        shouldShowChatSection ? kernel.allChatSectionHeaderItems : []
    }

    private var stackItems: [ChatSectionItem] {
        chatSectionItems.filter { $0.placement == .stack }
    }

    private var bottomItems: [ChatSectionItem] {
        chatSectionItems.filter { $0.placement == .bottomFixed }
    }

    var body: some View {
        Group {
            if shouldShowChatSection {
                ChatSectionView(
                    minWidth: chatSection.minWidth,
                    maxWidth: chatSection.maximumWidth,
                    toolbarBarItems: chatSectionToolbarBarItems,
                    headerItems: chatSectionHeaderItems,
                    stackItems: stackItems,
                    bottomItems: bottomItems,
                    rootContent: ChatSectionView.makeRootContent(
                        stackItems: stackItems,
                        bottomItems: bottomItems
                    )
                )
                .id("\(activeID)-\(chatSection.persistenceKeySuffix)")
                .layoutPriority(isRailOnlyPanel ? 1 : 0)
            }
        }
    }

    /// 返回用于 ChatSectionToolbarSync 的 toolbar items
    var toolbarItems: [ChatSectionToolbarItem] {
        chatSectionToolbarItems
    }
}
