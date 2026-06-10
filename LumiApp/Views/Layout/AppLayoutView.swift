import EditorService
import ChatPanelPlugin
import LumiCoreKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject private var layoutState = LumiLayoutStateStore.shared
    @StateObject private var panelLayoutState = PanelLayoutState()
    @ObservedObject var pluginService: PluginService
    let editorCoreService: EditorCoreService
    let lumiUIService: LumiUIService
    let chatService: any LumiChatServicing
    let chatSectionCoordinator: ChatSectionCoordinator
    let projectPathStore: LumiCurrentProjectPathStore

    var body: some View {
        let containers = pluginService.viewContainers(context: basePluginContext(showsChatSection: false))
        let selectedContainer = selectedContainer(from: containers)
        let activeID = selectedContainer?.id ?? "main"
        let activeTitle = selectedContainer?.title ?? "Main"
        let showsChatSection = selectedContainer?.showsChatSection ?? false
        let showsPanelChrome = selectedContainer?.showsPanelChrome ?? false
        let pluginContext = basePluginContext(
            activeSectionID: activeID,
            activeSectionTitle: activeTitle,
            showsChatSection: showsChatSection,
            showsPanelChrome: showsPanelChrome
        )
        let chatSectionItems = pluginService.chatSectionItems(context: pluginContext)
        let headerItems = pluginService.panelHeaderItems(context: pluginContext)
        let bottomTabs = pluginService.panelBottomTabItems(context: pluginContext)
        let railTabs = pluginService.panelRailTabItems(context: pluginContext)
        let shouldShowChatSection = showsChatSection
            && layoutState.chatSectionVisible
            && !chatSectionItems.isEmpty
        let showRail = showsPanelChrome
            && panelLayoutState.railVisible
            && !railTabs.isEmpty
        let autosaveName = layoutAutosaveName(showRail: showRail, showChatSection: shouldShowChatSection)

        VStack(spacing: 0) {
            AppTitleToolbar(
                pluginService: pluginService,
                activeID: activeID,
                activeTitle: activeTitle,
                projectPathStore: projectPathStore
            )

            AppDivider()

            Group {
                if shouldShowChatSection || showRail {
                    HSplitView {
                        ActivityBar(
                            layoutState: layoutState,
                            containers: containers
                        )

                        panelColumn(
                            container: selectedContainer,
                            headerItems: headerItems,
                            bottomTabs: bottomTabs,
                            showsPanelChrome: showsPanelChrome,
                            showRail: showRail,
                            railTabs: railTabs
                        )

                        if shouldShowChatSection {
                            ChatSectionView(
                                stackItems: chatSectionItems.filter { $0.placement == .stack },
                                bottomItems: chatSectionItems.filter { $0.placement == .bottomFixed },
                                rootContent: pluginService.chatSectionRootWrapper(
                                    context: pluginContext,
                                    content: ChatSectionView.makeRootContent(
                                        stackItems: chatSectionItems.filter { $0.placement == .stack },
                                        bottomItems: chatSectionItems.filter { $0.placement == .bottomFixed }
                                    )
                                )
                            )
                            .background(
                                SplitViewWidthPersistence(storageKey: "Layout.Main.ChatSection")
                            )
                        }
                    }
                    .background(
                        SplitViewAutosaveConfigurator(autosaveName: autosaveName)
                    )
                } else {
                    HStack(spacing: 0) {
                        ActivityBar(
                            layoutState: layoutState,
                            containers: containers
                        )

                        AppDivider(.vertical)

                        panelColumn(
                            container: selectedContainer,
                            headerItems: headerItems,
                            bottomTabs: bottomTabs,
                            showsPanelChrome: showsPanelChrome,
                            showRail: showRail,
                            railTabs: railTabs
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                selectDefaultContainerIfNeeded(containers)
            }
            .onChange(of: containers.map(\.id)) { _, _ in
                selectDefaultContainerIfNeeded(containers)
            }

            AppDivider()
            StatusBar(
                pluginService: pluginService,
                editorCoreService: editorCoreService,
                activeID: activeID,
                activeTitle: activeTitle,
                lumiUIService: lumiUIService,
                chatService: chatService,
                projectPathStore: projectPathStore
            )
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func panelColumn(
        container: LumiViewContainerItem?,
        headerItems: [LumiPanelHeaderItem],
        bottomTabs: [LumiPanelBottomTabItem],
        showsPanelChrome: Bool,
        showRail: Bool,
        railTabs: [LumiPanelRailTabItem]
    ) -> some View {
        let workspace = PanelWorkspaceView(
            container: container,
            headerItems: headerItems,
            bottomTabs: bottomTabs,
            showsPanelChrome: showsPanelChrome,
            layoutState: panelLayoutState
        )

        let column = Group {
            if showRail {
                HSplitView {
                    RailView(tabs: railTabs, layoutState: panelLayoutState)
                        .background(
                            SplitViewWidthPersistence(storageKey: "Layout.Main.Rail")
                        )
                    workspace
                }
            } else {
                workspace
            }
        }

        if showsPanelChrome {
            EditorScopeView(
                projectPathStore: projectPathStore,
                editor: editorCoreService
            ) {
                column
            }
            .modifier(PanelChromeCommandHandler(layoutState: panelLayoutState))
        } else {
            column
        }
    }

    private struct PanelChromeCommandHandler: ViewModifier {
        @ObservedObject var layoutState: PanelLayoutState

        private var notifications: EditorHostEnvironment.Notifications {
            EditorHostEnvironment.current.notifications
        }

        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: notifications.toggleOutlinePanel)) { _ in
                    layoutState.presentRailTab(id: "outline")
                }
                .onReceive(NotificationCenter.default.publisher(for: notifications.toggleOpenEditorsPanel)) { _ in
                    layoutState.presentRailTab(id: "explorer")
                }
        }
    }

    private func layoutAutosaveName(showRail: Bool, showChatSection: Bool) -> String {
        switch (showRail, showChatSection) {
        case (true, true):
            "Unified_MainSplit_Rail_ChatSection"
        case (true, false):
            "Unified_MainSplit_Rail"
        case (false, true):
            "Unified_MainSplit_ChatSection"
        case (false, false):
            "Unified_MainSplit"
        }
    }

    private func basePluginContext(
        activeSectionID: String? = nil,
        activeSectionTitle: String = "Main",
        showsChatSection: Bool = false,
        showsPanelChrome: Bool = false
    ) -> LumiPluginContext {
        LumiPluginContext(
            activeSectionID: activeSectionID ?? layoutState.activeViewContainerID ?? "main",
            activeSectionTitle: activeSectionTitle,
            showsChatSection: showsChatSection,
            showsPanelChrome: showsPanelChrome,
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiChatServicing.self, chatService)
                dependencies.register(LumiCurrentProjectPathStoring.self, projectPathStore)
                dependencies.register(LumiEditorServicing.self, editorCoreService)
                dependencies.register(ChatSectionCoordinator.self, chatSectionCoordinator)
            }
        )
    }

    private func selectedContainer(from containers: [LumiViewContainerItem]) -> LumiViewContainerItem? {
        if let activeID = layoutState.activeViewContainerID,
           let container = containers.first(where: { $0.id == activeID }) {
            return container
        }

        return containers.first
    }

    private func selectDefaultContainerIfNeeded(_ containers: [LumiViewContainerItem]) {
        guard !containers.isEmpty else {
            layoutState.activeViewContainerID = nil
            return
        }

        if let activeID = layoutState.activeViewContainerID,
           containers.contains(where: { $0.id == activeID }) {
            return
        }

        layoutState.activeViewContainerID = containers[0].id
    }
}
