import LumiKernel
import SuperLogKit
import SwiftUI
import os

struct SettingsCommand: Commands, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.settings")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(String(localized: "Settings...", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)Open settings window")
                }
                openWindow(id: AppBootstrap.settingsWindowID)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
