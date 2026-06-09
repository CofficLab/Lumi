import LumiCoreKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject private var layoutState = LumiLayoutStateStore.shared
    @ObservedObject var pluginService: PluginService
    let lumiUIService: LumiUIService
    let chatService: any LumiChatServicing
    let projectPathStore: LumiCurrentProjectPathStore

    var body: some View {
        let containers = pluginService.viewContainers(context: pluginContext)
        let selectedContainer = selectedContainer(from: containers)
        let activeID = selectedContainer?.id ?? "main"
        let activeTitle = selectedContainer?.title ?? "Main"

        VStack(spacing: 0) {
            AppTitleToolbar(
                pluginService: pluginService,
                activeID: activeID,
                activeTitle: activeTitle,
                projectPathStore: projectPathStore
            )

            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(
                    layoutState: layoutState,
                    containers: containers
                )

                AppDivider(.vertical)

                ContentWorkspaceView(container: selectedContainer)
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
                activeID: activeID,
                activeTitle: activeTitle,
                lumiUIService: lumiUIService,
                chatService: chatService,
                projectPathStore: projectPathStore
            )
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    private var pluginContext: LumiPluginContext {
        LumiPluginContext(
            activeSectionID: layoutState.activeViewContainerID ?? "main",
            activeSectionTitle: "Main",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiChatServicing.self, chatService)
                dependencies.register(LumiCurrentProjectPathStoring.self, projectPathStore)
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
