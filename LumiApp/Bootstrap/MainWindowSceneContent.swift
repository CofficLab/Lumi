import LumiChatKit
import LumiCoreKit
import SwiftUI

struct MainWindowSceneContent: View {
    @State private var container: RootContainer?
    @State private var initializationError: Error?
    @State private var isInitializing = true

    var body: some View {
        Group {
            if isInitializing {
                ProgressView("正在初始化...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            } else if let error = initializationError {
                CrashedView(error: error)
            } else if let container = container {
                RootView(container: container) {
                    AppLayoutView(
                        pluginService: container.pluginService,
                        editorCoreService: container.editorCoreService,
                        lumiUIService: container.lumiUIService,
                        chatService: RootContainer.checkedChatService,
                        chatSectionCoordinator: container.chatSectionCoordinator
                    )
                }
                .background {
                    WindowAccessor { window in
                        window.configureForLumiMainChrome()
                    }
                }
            }
        }
        .task {
            await initializeContainer()
        }
    }

    private func initializeContainer() async {
        do {
            let newContainer = try RootContainer()
            self.container = newContainer
        } catch {
            self.initializationError = error
        }
        self.isInitializing = false
    }
}
