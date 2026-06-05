import Foundation
import Testing
import AgentToolKit
import LumiCoreKit
@testable import ConversationNewPlugin

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationNewPlugin.policy == .alwaysOn)
    #expect(ConversationNewPlugin.isConfigurable == false)
}

@MainActor
@Test func windowConversationVMCreatesConversationWithProjectContext() async throws {
    var created: [(String?, String?, LanguagePreference, ChatMode?)] = []
    let conversationVM = WindowConversationVM(
        createNewConversationHandler: { projectName, projectPath, languagePreference, chatMode in
            created.append((projectName, projectPath, languagePreference, chatMode))
        }
    )

    await conversationVM.createNewConversation(
        projectName: "Lumi",
        projectPath: "/tmp/Lumi",
        languagePreference: .english,
        chatMode: .autonomous
    )

    #expect(created.count == 1)
    #expect(created.first?.0 == "Lumi")
    #expect(created.first?.1 == "/tmp/Lumi")
    #expect(created.first?.2 == .english)
    #expect(created.first?.3 == .autonomous)
}

@Test func localStorePersistsDefaultChatMode() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationNewStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveDefaultChatMode(ChatMode.autonomous)

    let reloadedStore = LocalStore(databaseDirectory: databaseDirectory)
    #expect(reloadedStore.loadDefaultChatMode() == .autonomous)
}
