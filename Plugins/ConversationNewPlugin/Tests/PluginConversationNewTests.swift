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
    var created: [(String?, String?, LanguagePreference)] = []
    let conversationVM = WindowConversationVM(
        createNewConversationHandler: { projectName, projectPath, languagePreference in
            created.append((projectName, projectPath, languagePreference))
        }
    )

    await conversationVM.createNewConversation(
        projectName: "Lumi",
        projectPath: "/tmp/Lumi",
        languagePreference: .english
    )

    #expect(created.count == 1)
    #expect(created.first?.0 == "Lumi")
    #expect(created.first?.1 == "/tmp/Lumi")
    #expect(created.first?.2 == .english)
}
