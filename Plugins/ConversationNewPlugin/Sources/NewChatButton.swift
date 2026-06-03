import SwiftUI
import LumiCoreKit
import LumiUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var projectVM: PluginProjectContext

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
                    languagePreference: projectVM.languagePreference
                )
            }
        }
    }
}
