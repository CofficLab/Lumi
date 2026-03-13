import MagicKit
import OSLog
import SwiftUI

/// 应用模式切换器，在 App 模式和 Agent 模式之间切换
struct AppModeSwitcherView: View, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @Environment(\.windowState) var windowState

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
        // 优先使用窗口级别的模式状态，如果没有则使用全局状态
        self.mode = windowState?.selectedMode ?? app.selectedMode
    }

    func handleModeChanged() {
        if Self.verbose {
            os_log("\(self.t)🤖 模式已切换：\(mode.rawValue)")
        }
        
        // 同时更新窗口级别和全局级别的模式状态
        windowState?.selectedMode = mode
        app.selectedMode = mode
    }
}

// MARK: - Preview

#Preview("AppModeSwitcherView") {
    AppModeSwitcherView()
        .padding()
        .inRootView()
}
