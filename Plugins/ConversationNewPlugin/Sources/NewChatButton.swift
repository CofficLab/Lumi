import LumiCoreKit
import LumiUI
import SwiftUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let chatService: any LumiChatServicing
    let projectComponent: ProjectComponent?
    let lumiCore: (any LumiCoreAccessing)?

    @State private var localStore: LocalStore?

    public init(
        chatService: any LumiChatServicing,
        projectComponent: ProjectComponent? = nil,
        lumiCore: (any LumiCoreAccessing)? = nil
    ) {
        self.chatService = chatService
        self.projectComponent = projectComponent
        self.lumiCore = lumiCore
    }

    public var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: LumiPluginLocalization.string("Start New Conversation", bundle: .module)
        ) {
            createConversation()
        }
        .onAppear {
            syncDefaultAutomationLevel()
        }
    }

    func syncDefaultAutomationLevel(using localStore: LocalStore? = nil) {
        let store = localStore ?? resolvedLocalStore()
        store.saveDefaultAutomationLevel(
            chatService.automationLevel(for: chatService.selectedConversationID)
        )
    }

    func createConversation(using localStore: LocalStore? = nil) {
        let store = localStore ?? resolvedLocalStore()
        let projectPath = projectComponent?.currentProject?.path
        let resolvedPath = (projectPath?.isEmpty == false) ? projectPath : nil
        let language = chatService.language(for: chatService.selectedConversationID)
        let automationLevel = store.loadDefaultAutomationLevel()
            ?? chatService.automationLevel(for: chatService.selectedConversationID)

        let conversationID = chatService.createConversation(
            title: nil,
            projectPath: resolvedPath,
            language: language
        )
        chatService.setAutomationLevel(automationLevel, for: conversationID)
    }

    private func resolvedLocalStore() -> LocalStore {
        if let localStore {
            return localStore
        }
        let store = LocalStore(databaseDirectory: lumiCore?.coreDataDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
        localStore = store
        return store
    }
}
