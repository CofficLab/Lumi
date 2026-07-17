import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

public struct WindowSettings: View {
    @State private var container: RootContainer?
    @State private var initializationError: Error?
    @State private var isInitializing = true

    public init() {}

    public var body: some View {
        contentView
            .task {
                await initializeContainer()
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if isInitializing {
            ProgressView("正在初始化...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        } else if let error = initializationError {
            CrashedView(error: error)
        } else if let container = container {
            RootView(container: container, appliesRootOverlays: false) {
                SettingsView(
                    lumiCore: container.lumiCore,
                    pluginService: container.pluginService,
                    lumiUIService: container.lumiUIService,
                    chatService: container.lumiCoreService.chatService
                )
                .ignoresSafeArea()
            }
            .background {
                WindowAccessor { window in
                    window.configureForLumiMainChrome()
                }
                ThemeWindowAppearanceBridge()
            }
            .ignoresSafeArea()
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
