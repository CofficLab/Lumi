import EditorService
import LumiCoreKit
import LumiChatKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject private var layoutState: LumiLayoutState
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
        let headerItems = pluginService.panelHeaderItems(context: preliminaryPluginContext)
        let bottomTabs = pluginService.panelBottomTabItems(context: preliminaryPluginContext)
        let railTabs = pluginService.panelRailTabItems(context: preliminaryPluginContext)
        let showRail = showsRail && !railTabs.isEmpty
        let isRailOnlyPanel = showRail && !showsPanelChrome
        let autosaveName = layoutAutosaveName(
            showRail: showRail,
            showChatSection: chatSection.isVisible,
            chatSection: chatSection
        )
        let chatView = ChatView(
            layoutState: layoutState,
            pluginService: pluginService,
            context: preliminaryPluginContext,
            chatSectionCoordinator: chatSectionCoordinator,
            chatSection: chatSection,
            activeID: activeID,
            isRailOnlyPanel: isRailOnlyPanel
        )

        VStack(spacing: 0) {
            AppTitleToolbar(
                pluginService: pluginService,
                pluginContext: preliminaryPluginContext
            )

            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(
                    layoutState: layoutState,
                    containers: containers
                )

                if chatSection.isVisible || showRail {
                    HSplitView {
                        PanelColumnView(
                            container: selectedContainer,
                            headerItems: headerItems,
                            bottomTabs: bottomTabs,
                            showsPanelChrome: showsPanelChrome,
                            showRail: showRail,
                            railTabs: railTabs,
                            layoutState: layoutState,
                            editor: editorCoreService
                        )
                        .layoutPriority(isRailOnlyPanel ? 0 : 1)
                        .frame(
                            maxWidth: isRailOnlyPanel ? nil : .infinity,
                            maxHeight: .infinity
                        )
                        .borderTrailing()

                        chatView
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
                        layoutState: layoutState,
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
                pluginContext: preliminaryPluginContext,
                lumiUIService: lumiUIService,
                chatService: chatService,
                layoutState: layoutState
            )
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .background {
            ChatSectionToolbarSync(
                items: chatView.toolbarItems,
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
        LumiCore.makePluginContext(
            activeSectionID: activeSectionID ?? layoutState.activeViewContainerID ?? "main",
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            additionalDependencies: { dependencies in
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
