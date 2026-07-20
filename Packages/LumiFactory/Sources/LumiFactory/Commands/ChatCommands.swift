import LumiCoreMessage
import LumiLocalizationKit
import SwiftUI

struct ChatCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button(String(localized: "Focus Chat Input", bundle: .module)) {
                NotificationCenter.default.post(name: .lumiFocusChatInput, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button(String(localized: "Send Message", bundle: .module)) {
                NotificationCenter.default.post(name: .lumiSendChatMessage, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button(String(localized: "Stop Generation", bundle: .module)) {
                NotificationCenter.default.post(name: .lumiStopChatGeneration, object: nil)
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
    }
}
