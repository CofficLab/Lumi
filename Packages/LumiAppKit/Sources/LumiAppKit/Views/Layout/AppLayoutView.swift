import EditorService
import LumiCoreKit
import LumiChatKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var lumiCore: LumiCore
    @ObservedObject var pluginService: PluginService
    let editorCoreService: EditorCoreService
    let lumiUIService: LumiUIService
    let chatService: ChatService
    let chatSectionCoordinator: ChatSectionCoordinator

    init(
        lumiCore: LumiCore,
        pluginService: PluginService,
        editorCoreService: EditorCoreService,
        lumiUIService: LumiUIService,
        chatService: ChatService,
        chatSectionCoordinator: ChatSectionCoordinator
    ) {
        self.lumiCore = lumiCore
        self.pluginService = pluginService
        self.editorCoreService = editorCoreService
        self.lumiUIService = lumiUIService
        self.chatService = chatService
        self.chatSectionCoordinator = chatSectionCoordinator
    }

    /// 优先使用 boot() 之后的 layoutState;未就绪时退化到 fresh 实例。
    /// LumiCore 本身是 ObservableObject,layoutState 变化会触发 body 重绘。
    private var layoutState: LumiLayoutState {
        lumiCore.layoutState ?? LumiLayoutState()
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
                        Group {
                            if chatSection.isVisible {
                                SplitViewDividerPersistence.chatSection(
                                    layoutState: layoutState,
                                    viewContainerID: activeID,
                                    layout: chatSection
                                )
                            }
                        }
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
                chatService: chatService
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

    private func basePluginContext(
        activeSectionID: String? = nil,
        activeSectionTitle: String = "Main",
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil
    ) -> LumiPluginContext {
        lumiCore.makePluginContext(
            activeSectionID: activeSectionID ?? layoutState.activeViewContainerID ?? "main",
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            additionalDependencies: { dependencies in
                dependencies.register(ChatSectionCoordinator.self, chatSectionCoordinator)
                dependencies.register((any LumiEditorServicing).self, editorCoreService)
                dependencies.register(LumiThemeServicing.self, lumiUIService)
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

    private func selectDefaultContainerIfNeeded(_ containers: [LumiViewContainerItem]) -> Void {
        // 布局尚未从磁盘恢复时，不写默认选择——否则首帧默认值会覆盖即将恢复的持久化值。
        // restore 通常已在 RootContainer.init 同步阶段完成（isLayoutRestored == true），
        // 此守卫作防御性兜底，防止未来 restore 时序被改回异步后再次踩坑。
        guard layoutState.isLayoutRestored else { return }

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
