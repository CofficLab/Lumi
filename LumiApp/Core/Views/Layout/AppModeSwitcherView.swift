import SwiftUI

/// 应用模式切换器，在 App 模式和 Agent 模式之间切换
struct AppModeSwitcherView: View {
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var pluginProvider: PluginProvider

    @State private var mode: AppMode = .app

    var body: some View {
        Picker("模式", selection: $mode) {
            ForEach(AppMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onChange(of: self.mode) {
            pluginProvider.selectedMode = self.mode
            app.selectedMode = self.mode
        }
    }
}

#Preview("AppModeSwitcherView") {
    AppModeSwitcherView()
        .padding()
        .inRootView()
}
