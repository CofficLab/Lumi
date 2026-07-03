import LumiChatKit
import LumiCoreKit
import SwiftUI

struct MainWindowSceneContent: View {
    @StateObject private var container = RootContainer.shared

    var body: some View {
        RootView(container: container) {
            AppLayoutView(
                pluginService: container.pluginService,
                editorCoreService: container.editorCoreService,
                lumiUIService: container.lumiUIService,
                chatService: LumiCore.chatService as! ChatService,
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
