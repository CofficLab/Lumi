import EditorService
import LumiCoreKit
import LumiChatKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject private var layoutState: LumiLayoutState
    @StateObject private var panelLayoutState = PanelLayoutState()
    @ObservedObject var pluginService: PluginService
    let editorCoreService: EditorCoreService
    let lumiUIService: LumiUIService
    let chatService: ChatService
    let chatSectionCoordinator: ChatSectionCoordinator

    init(
        pluginService: PluginService,
        editorCoreService: EditorCoreService,
        lumiUIService: LumiUIService,
        chatService: ChatService,
        chatSectionCoordinator: ChatSectionCoordinator
    ) {
        self.pluginService = pluginService
        self.editorCoreService = editorCoreService
        self.lumiUIService = lumiUIService
        self.chatService = chatService
        self.chatSectionCoordinator = chatSectionCoordinator
        _layoutState = ObservedObject(initialValue: LumiCore.layoutState ?? LumiLayoutState())
    }

    var body: some View {
        let containers = pluginService.viewContainers(context: basePluginContext())
        let selectedContainer = selectedContainer(from: containers)
        let activeID = selectedContainer?.id ?? "main"
        let activeTitle = selectedContainer?.title ?? "Main"
        let chatSection = selectedContainer?.chatSection ?? .none
        let showsRail = selectedContainer?.showsRail ?? false
        let showsPanelChrome = selectedContainer?.showsPanelChrome ?? false
        let preliminaryPluginContext = basePluginContext(
            activeSectionID: activeID,
            activeSectionTitle: activeTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: chatSection.isVisible
        )
        let chatSectionItems = pluginService.chatSectionItems(context: preliminaryPluginContext)
        let shouldShowChatSection = chatSection.isVisible
            && layoutState.chatSectionVisible
            && !chatSectionItems.isEmpty
        let pluginContext = basePluginContext(
            activeSectionID: activeID,
            activeSectionTitle: activeTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: shouldShowChatSection
        )
        let chatSectionToolbarItems = shouldShowChatSection
            ? pluginService.chatSectionToolbarItems(context: pluginContext)
            : []
        let chatSectionToolbarBarItems = shouldShowChatSection
            ? pluginService.chatSectionToolbarBarItems(context: pluginContext)
            : []
        let chatSectionHeaderItems = shouldShowChatSection
            ? pluginService.chatSectionHeaderItems(context: pluginContext)
            : []
        let headerItems = pluginService.panelHeaderItems(context: pluginContext)
        let bottomTabs = pluginService.panelBottomTabItems(context: pluginContext)
        let railTabs = pluginService.panelRailTabItems(context: pluginContext)
        let showRail = showsRail && !railTabs.isEmpty
        let isRailOnlyPanel = showRail && !showsPanelChrome
        let autosaveName = layoutAutosaveName(
            showRail: showRail,
            showChatSection: shouldShowChatSection,
            chatSection: chatSection
        )

        VStack(spacing: 0) {
            AppTitleToolbar(
                pluginService: pluginService,
                pluginContext: pluginContext
            )

            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(
                    layoutState: layoutState,
                    containers: containers
                )

                if shouldShowChatSection || showRail {
                    HSplitView {
                        PanelColumnView(
                            container: selectedContainer,
                            headerItems: headerItems,
                            bottomTabs: bottomTabs,
                            showsPanelChrome: showsPanelChrome,
                            showRail: showRail,
                            railTabs: railTabs,
                            layoutState: panelLayoutState,
                            editor: editorCoreService
                        )
                        .layoutPriority(isRailOnlyPanel ? 0 : 1)
                        .frame(
                            maxWidth: isRailOnlyPanel ? nil : .infinity,
                            maxHeight: .infinity
                        )
                        .borderTrailing()

                        if shouldShowChatSection {
                            let stackItems = chatSectionItems.filter { $0.placement == .stack }
                            let bottomItems = chatSectionItems.filter { $0.placement == .bottomFixed }
                            
                            ChatSectionView(
                                layout: chatSection,
                                toolbarBarItems: chatSectionToolbarBarItems,
                                headerItems: chatSectionHeaderItems,
                                stackItems: stackItems,
                                bottomItems: bottomItems,
                                rootContent: pluginService.chatSectionRootWrapper(
                                    context: pluginContext,
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
                    .background(
                        SplitViewAutosaveConfigurator(autosaveName: autosaveName)
                    )
                } else {
                    AppDivider(.vertical)

                    PanelColumnView(
                        container: selectedContainer,
                        headerItems: headerItems,
                        bottomTabs: bottomTabs,
                        showsPanelChrome: showsPanelChrome,
                        showRail: showRail,
                        railTabs: railTabs,
                        layoutState: panelLayoutState,
                        editor: editorCoreService
                    )
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
                pluginContext: pluginContext,
                lumiUIService: lumiUIService,
                chatService: chatService,
                panelLayoutState: panelLayoutState
            )
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .background {
            ChatSectionToolbarSync(
                items: chatSectionToolbarItems,
                coordinator: chatSectionCoordinator
            )
        }
        .ignoresSafeArea()
    }

    private func layoutAutosaveName(
        showRail: Bool,
        showChatSection: Bool,
        chatSection: LumiChatSectionLayout
    ) -> String {
        let chatSuffix = showChatSection ? "_\(chatSection.persistenceKeySuffix)" : ""
        return switch (showRail, showChatSection) {
        case (true, true):
            "Unified_MainSplit_Rail_ChatSection\(chatSuffix)"
        case (true, false):
            "Unified_MainSplit_Rail"
        case (false, true):
            "Unified_MainSplit_ChatSection\(chatSuffix)"
        case (false, false):
            "Unified_MainSplit"
        }
    }

    private func basePluginContext(
        activeSectionID: String? = nil,
        activeSectionTitle: String = "Main",
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil
    ) -> LumiPluginContext {
        LumiPluginContext(
            activeSectionID: activeSectionID ?? layoutState.activeViewContainerID ?? "main",
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register((any LumiChatServicing).self, chatService)
                dependencies.register(LumiEditorServicing.self, editorCoreService)
                dependencies.register(ChatSectionCoordinator.self, chatSectionCoordinator)
                dependencies.register(LumiBottomPanelLayoutPresenting.self, panelLayoutState)
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

        if let activeID = layoutState.activeViewContainerID {
            if containers.contains(where: { $0.id == activeID }) {
                return
            }
            if isViewContainerExpected(activeID) {
                return
            }
        }

        layoutState.activeViewContainerID = containers[0].id
    }

    private func isViewContainerExpected(_ containerID: String) -> Bool {
        pluginService.enabledPlugins.contains { $0.info.id == containerID }
    }
}
