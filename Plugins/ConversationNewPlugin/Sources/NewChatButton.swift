import SwiftUI
import LumiCoreKit
import LumiUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var projectVM: PluginProjectContext
    @EnvironmentObject private var llmVM: AppLLMVM

    public init() {}

    public var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: String(localized: "Start New Conversation", bundle: .module)
        ) {
            Task {
                await conversationVM.createNewConversation(
                    projectName: projectVM.isProjectSelected ? projectVM.currentProjectName : nil,
                    projectPath: projectVM.isProjectSelected ? projectVM.currentProjectPath : nil,
                    languagePreference: projectVM.languagePreference,
                    chatMode: defaultChatMode()
                )
            }
        }
        .onAppear {
            syncDefaultChatMode(llmVM.chatMode)
        }
        .onChange(of: llmVM.chatMode) { _, newMode in
            syncDefaultChatMode(newMode)
        }
    }

    private func defaultChatMode() -> ChatMode {
        localStore().loadDefaultChatMode() ?? llmVM.chatMode
    }

    private func syncDefaultChatMode(_ chatMode: ChatMode) {
        localStore().saveDefaultChatMode(chatMode)
    }

    private func localStore() -> LocalStore {
        LocalStore(databaseDirectory: conversationVM.databaseDirectory())
    }
}
