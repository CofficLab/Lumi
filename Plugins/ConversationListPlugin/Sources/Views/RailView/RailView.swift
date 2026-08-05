import LumiKernel
import SwiftUI

/// 对话列表侧栏视图：组合 HeaderBarView 与 ListView。
struct RailView: View {
    @ObservedObject private var kernel: LumiKernel
    private let attentionStore: ConversationAttentionStore
    private let scopeToCurrentProject: Bool

    init(kernel: LumiKernel, attentionStore: ConversationAttentionStore, scopeToCurrentProject: Bool = false) {
        self._kernel = ObservedObject(wrappedValue: kernel)
        self.attentionStore = attentionStore
        self.scopeToCurrentProject = scopeToCurrentProject
    }

    private var projectPath: String? {
        guard scopeToCurrentProject else { return nil }
        return kernel.project?.currentProject?.path
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBarView(scopeToCurrentProject: scopeToCurrentProject, kernel: kernel)

            if let conversationManager = kernel.conversationManager {
                ListView(
                    kernel: kernel,
                    conversationManager: conversationManager,
                    attentionStore: attentionStore,
                    projectPath: projectPath
                )
            } else {
                ListErrorView(reason: "Conversation store service is not available")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
