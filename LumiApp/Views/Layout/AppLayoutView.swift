import LumiCoreKit
import LumiUI
import SwiftUI

struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var pluginService: PluginService
    let lumiUIService: LumiUIService
    let chatService: any LumiChatServicing
    @State private var state = LayoutState()

    var body: some View {
        let containers = pluginService.viewContainers(context: pluginContext)
        let selectedContainer = selectedContainer(from: containers)
        let activeID = selectedContainer?.id ?? "main"
        let activeTitle = selectedContainer?.title ?? "Main"

        VStack(spacing: 0) {
            AppTitleToolbar(
                state: $state,
                pluginService: pluginService,
                activeID: activeID,
                activeTitle: activeTitle
            )

            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(
                    state: $state,
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
                state: state,
                pluginService: pluginService,
                activeID: activeID,
                activeTitle: activeTitle,
                lumiUIService: lumiUIService,
                chatService: chatService
            )
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    private var pluginContext: LumiPluginContext {
        LumiPluginContext(
            activeSectionID: state.activeViewContainerID ?? "main",
            activeSectionTitle: "Main",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiChatServicing.self, chatService)
            }
        )
    }

    private func selectedContainer(from containers: [LumiViewContainerItem]) -> LumiViewContainerItem? {
        if let activeID = state.activeViewContainerID,
           let container = containers.first(where: { $0.id == activeID }) {
            return container
        }

        return containers.first
    }

    private func selectDefaultContainerIfNeeded(_ containers: [LumiViewContainerItem]) {
        guard !containers.isEmpty else {
            state.activeViewContainerID = nil
            return
        }

        if let activeID = state.activeViewContainerID,
           containers.contains(where: { $0.id == activeID }) {
            return
        }

        state.activeViewContainerID = containers[0].id
    }
}
