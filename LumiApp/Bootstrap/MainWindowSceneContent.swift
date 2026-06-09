import SwiftUI

struct MainWindowSceneContent: View {
    @StateObject private var container = RootContainer.shared

    var body: some View {
        RootView(container: container) {
            AppLayoutView(
                pluginService: container.pluginService,
                lumiUIService: container.lumiUIService,
                chatService: container.chatCoreService.chatService,
                projectPathStore: container.projectPathStore
            )
        }
        .background {
            WindowAccessor { window in
                window.configureForLumiMainChrome()
            }
        }
    }
}
