import LumiCoreKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// 负责整合 Chat 视图相关的代码
/// 封装了 ChatSection 的可见性判断、items 获取等逻辑
struct ChatView: View {
    @ObservedObject private var layoutState: LayoutState
    let pluginService: PluginService
    let context: LumiPluginContext
    let chatSectionCoordinator: ChatSectionCoordinator
    let chatSection: LumiChatSectionLayout
    let activeID: String
    let isRailOnlyPanel: Bool

    init(
        layoutState: LayoutState,
        pluginService: PluginService,
        context: LumiPluginContext,
        chatSectionCoordinator: ChatSectionCoordinator,
        chatSection: LumiChatSectionLayout,
        activeID: String,
        isRailOnlyPanel: Bool
    ) {
        self.layoutState = layoutState
        self.pluginService = pluginService
        self.context = context
        self.chatSectionCoordinator = chatSectionCoordinator
        self.chatSection = chatSection
        self.activeID = activeID
        self.isRailOnlyPanel = isRailOnlyPanel
    }

    private var chatSectionItems: [LumiChatSectionItem] {
        pluginService.chatSectionItems(context: context)
    }

    private var shouldShowChatSection: Bool {
        let result = chatSection.isVisible
            && layoutState.chatSectionVisible
        return result
    }

    private var finalContext: LumiPluginContext {
        LumiPluginContext(
            activeSectionID: context.activeSectionID,
            activeSectionTitle: context.activeSectionTitle,
            chatSection: context.chatSection,
            showsRail: context.showsRail,
            showsPanelChrome: context.showsPanelChrome,
            isChatSectionVisible: shouldShowChatSection,
            dependencies: context.dependencies
        )
    }

    private var chatSectionToolbarItems: [LumiChatSectionToolbarItem] {
        shouldShowChatSection
            ? pluginService.chatSectionToolbarItems(context: finalContext)
            : []
    }

    private var chatSectionToolbarBarItems: [LumiChatSectionToolbarBarItem] {
        shouldShowChatSection
            ? pluginService.chatSectionToolbarBarItems(context: finalContext)
            : []
    }

    private var chatSectionHeaderItems: [LumiChatSectionHeaderItem] {
        shouldShowChatSection
            ? pluginService.chatSectionHeaderItems(context: finalContext)
            : []
    }

    private var stackItems: [LumiChatSectionItem] {
        chatSectionItems.filter { $0.placement == .stack }
    }

    private var bottomItems: [LumiChatSectionItem] {
        chatSectionItems.filter { $0.placement == .bottomFixed }
    }

    var body: some View {
        Group {
            if shouldShowChatSection {
                ChatSectionView(
                    layout: chatSection,
                    toolbarBarItems: chatSectionToolbarBarItems,
                    headerItems: chatSectionHeaderItems,
                    stackItems: stackItems,
                    bottomItems: bottomItems,
                    rootContent: pluginService.chatSectionRootWrapper(
                        context: finalContext,
                        content: ChatSectionView.makeRootContent(
                            stackItems: stackItems,
                            bottomItems: bottomItems
                        )
                    )
                )
                .id("\(activeID)-\(chatSection.persistenceKeySuffix)")
                .layoutPriority(isRailOnlyPanel ? 1 : 0)
            }
        }
    }

    /// 返回用于 ChatSectionToolbarSync 的 toolbar items
    var toolbarItems: [LumiChatSectionToolbarItem] {
        chatSectionToolbarItems
    }
}
