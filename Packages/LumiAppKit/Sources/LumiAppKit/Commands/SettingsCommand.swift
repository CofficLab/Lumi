import SwiftUI
import SuperLogKit
import os

struct SettingsCommand: Commands, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.settings")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("设置...") {
                if Self.verbose {
                    Self.logger.info("\(Self.t)打开设置窗口")
                }
                openWindow(id: AppBootstrap.settingsWindowID)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
