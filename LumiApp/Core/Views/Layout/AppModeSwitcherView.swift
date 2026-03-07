import MagicKit
import OSLog
import SwiftUI

/// 应用模式切换器，在 App 模式和 Agent 模式之间切换
struct AppModeSwitcherView: View, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    @EnvironmentObject var app: GlobalProvider
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
        .onAppear(perform: handleOnAppear)
        .onChange(of: self.mode, handleModeChanged)
    }
}

// MARK: - Event Handler

extension AppModeSwitcherView {
    func handleOnAppear() {
        self.mode = app.selectedMode
    }

    func handleModeChanged() {
        if Self.verbose {
            os_log("\(self.t)模式已切换：\(mode.rawValue)")
        }
        
        app.selectedMode = mode
    }
}

// MARK: - Preview

#Preview("AppModeSwitcherView") {
    AppModeSwitcherView()
        .padding()
        .inRootView()
}
