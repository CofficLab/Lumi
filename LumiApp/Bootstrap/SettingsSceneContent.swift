import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct SettingsSceneContent: View {
    @StateObject private var container = RootContainer.shared

    var body: some View {
        RootView(container: container, appliesRootOverlays: false) {
            SettingsView(
                pluginService: container.pluginService,
                lumiUIService: container.lumiUIService,
                chatService: LumiCore.chatService as! ChatService
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
