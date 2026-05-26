import LumiUI
import SwiftUI

struct AppLoadedPluginsStatusBarView: View {
    let pluginProvider: @MainActor () -> [LoadedPluginInfo]

    var body: some View {
        StatusBarHoverContainer(
            detailView: AppLoadedPluginsDetailView(pluginProvider: pluginProvider),
            popoverWidth: 460,
            id: "lumi-app-loaded-plugins"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}
