import EditorService
import ChatPanelPlugin
import LumiCoreKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject private var layoutState = LumiLayoutStateStore.shared
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
        let pluginContext = basePluginContext(
            activeSectionID: activeID,
            activeSectionTitle: activeTitle,
            showsChatSection: showsChatSection
        )
        let chatSectionItems = pluginService.chatSectionItems(context: pluginContext)
        let shouldShowChatSection = showsChatSection
            && layoutState.chatSectionVisible
            && !chatSectionItems.isEmpty

        VStack(spacing: 0) {
            AppTitleToolbar(
                pluginService: pluginService,
                activeID: activeID,
                activeTitle: activeTitle,
                projectPathStore: projectPathStore
            )

            AppDivider()

            Group {
                if shouldShowChatSection {
                    HSplitView {
                        ActivityBar(
                            layoutState: layoutState,
                            containers: containers
                        )

                        ContentWorkspaceView(container: selectedContainer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    .background(
                        SplitViewAutosaveConfigurator(autosaveName: "Unified_MainSplit_ChatSection")
                    )
                } else {
                    HStack(spacing: 0) {
                        ActivityBar(
                            layoutState: layoutState,
                            containers: containers
                        )

                        AppDivider(.vertical)

                        ContentWorkspaceView(container: selectedContainer)
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

    private func basePluginContext(
        activeSectionID: String? = nil,
        activeSectionTitle: String = "Main",
        showsChatSection: Bool = false
    ) -> LumiPluginContext {
        LumiPluginContext(
            activeSectionID: activeSectionID ?? layoutState.activeViewContainerID ?? "main",
            activeSectionTitle: activeSectionTitle,
            showsChatSection: showsChatSection,
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
