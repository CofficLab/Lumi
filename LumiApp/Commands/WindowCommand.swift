import SwiftUI
import SuperLogKit
import os

struct WindowCommand: Commands, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.window")
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose = true

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                if Self.verbose {
                    Self.logger.info("\(Self.t)新建窗口")
                }
                openWindow(id: AppBootstrap.mainWindowID)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
