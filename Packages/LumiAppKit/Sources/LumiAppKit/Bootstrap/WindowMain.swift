import LumiChatKit
import LumiCoreKit
import SwiftUI

public struct WindowMain: View {
    @State private var container: RootContainer?
    @State private var initializationError: Error?
    @State private var isInitializing = true

    public init() {}

    public var body: some View {
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
                        chatService: RootContainer.checkedChatService(container.lumiCore),
                        chatSectionCoordinator: container.chatSectionCoordinator
                    )
                }
                // 把 LumiCore 注入到 SwiftUI 视图树,让 App + 插件视图通过
                // @EnvironmentObject var lumiCore: LumiCore 访问核心状态
                .environmentObject(container.lumiCore)
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
            // 把 LumiCore 注入到 OpenProjectHandler(单例),让外部
            // `application(_:openFile:)` 路径也能切换项目。
            OpenProjectHandler.shared.configure(lumiCore: newContainer.lumiCore)
        } catch {
            self.initializationError = error
        }
        self.isInitializing = false
    }
}
