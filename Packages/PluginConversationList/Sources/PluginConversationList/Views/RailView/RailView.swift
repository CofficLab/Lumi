import SwiftUI

/// 对话列表侧栏视图：组合 HeaderBarView 与 ListView。
struct RailView: View {
    private let attentionStore: ConversationAttentionStore
    @ObservedObject private var sortStabilizer: ConversationSortStabilizer
    private let context: ConversationListContext
    private let scopeToCurrentProject: Bool

    init(
        context: ConversationListContext,
        attentionStore: ConversationAttentionStore,
        sortStabilizer: ConversationSortStabilizer,
        scopeToCurrentProject: Bool = false
    ) {
        self.context = context
        self.attentionStore = attentionStore
        self._sortStabilizer = ObservedObject(wrappedValue: sortStabilizer)
        self.scopeToCurrentProject = scopeToCurrentProject
    }

    private var projectPath: String? {
        guard scopeToCurrentProject else { return nil }
        return context.currentProjectPath
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBarView(scopeToCurrentProject: scopeToCurrentProject, context: context)

            ListView(
                context: context,
                attentionStore: attentionStore,
                sortStabilizer: sortStabilizer,
                projectPath: projectPath
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
