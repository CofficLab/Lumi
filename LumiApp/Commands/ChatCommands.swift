import LumiCoreKit
import SwiftUI

struct ChatCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Focus Chat Input") {
                NotificationCenter.default.post(name: .lumiFocusChatInput, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Send Message") {
                NotificationCenter.default.post(name: .lumiSendChatMessage, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("Stop Generation") {
                NotificationCenter.default.post(name: .lumiStopChatGeneration, object: nil)
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
    }
}
