import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct SettingsSceneContent: View {
    @StateObject private var container = RootContainer.shared

    var body: some View {
        Group {
            if let error = container.initializationError {
                CrashedView(error: error)
            } else {
                RootView(container: container, appliesRootOverlays: false) {
                    SettingsView(
                        pluginService: container.pluginService,
                        lumiUIService: container.lumiUIService,
                        chatService: RootContainer.checkedChatService
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
    }
}
