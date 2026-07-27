import LumiKernel
import SuperLogKit
import SwiftUI
import os

struct WindowCommand: Commands, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.window")
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose = false

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(String(localized: "New Window", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)New window")
                }
                openWindow(id: AppBootstrap.mainWindowID)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
