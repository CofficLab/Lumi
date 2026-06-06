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

@MainActor
@Test func toolbarViewShowsButtonWhenChatVisible() async throws {
    let missingCapabilityContext = PluginContext(showChat: .narrow)
    let hiddenChatContext = PluginContext(showChat: .hidden)
    let creationContext = ConversationCreationContext(
        isProjectSelectedProvider: { false },
        projectNameProvider: { "" },
        projectPathProvider: { "" },
        languagePreferenceProvider: { .english },
        currentChatModeProvider: { .build },
        defaultChatModeProvider: { nil },
        defaultChatModeSaver: { _ in },
        conversationCreator: { _, _, _, _ in }
    )
    let context = PluginContext(showChat: .narrow, conversationCreationContext: creationContext)

    #expect(ConversationNewPlugin.shared.addToolBarTrailingView(context: missingCapabilityContext) != nil)
    #expect(ConversationNewPlugin.shared.addToolBarTrailingView(context: hiddenChatContext) == nil)
    #expect(ConversationNewPlugin.shared.addToolBarTrailingView(context: context) != nil)
}

@MainActor
@Test func conversationCreationContextCreatesConversationWithInjectedState() async throws {
    var savedDefaultMode: ChatMode?
    var created: [(String?, String?, LanguagePreference, ChatMode?)] = []
    let context = ConversationCreationContext(
        isProjectSelectedProvider: { true },
        projectNameProvider: { "Lumi" },
        projectPathProvider: { "/tmp/Lumi" },
        languagePreferenceProvider: { .english },
        currentChatModeProvider: { .autonomous },
        defaultChatModeProvider: { .build },
        defaultChatModeSaver: { savedDefaultMode = $0 },
        conversationCreator: { projectName, projectPath, languagePreference, chatMode in
            created.append((projectName, projectPath, languagePreference, chatMode))
        }
    )

    context.syncDefaultChatMode()
    await context.createConversation()

    #expect(savedDefaultMode == .autonomous)
    #expect(created.count == 1)
    #expect(created.first?.0 == "Lumi")
    #expect(created.first?.1 == "/tmp/Lumi")
    #expect(created.first?.2 == .english)
    #expect(created.first?.3 == .build)
}
