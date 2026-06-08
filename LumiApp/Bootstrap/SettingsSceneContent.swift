import SwiftUI

struct SettingsSceneContent: View {
    @StateObject private var container = RootContainer.shared

    var body: some View {
        RootView(container: container) {
            SettingsView(
                pluginService: container.pluginService,
                lumiUIService: container.lumiUIService
            )
        }
        .background {
            WindowAccessor { window in
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
            }
        }
    }
}
