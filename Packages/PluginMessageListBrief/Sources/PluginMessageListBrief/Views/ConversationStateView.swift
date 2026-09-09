import SwiftUI

/// 消息列表尾部的当前对话状态视图。
struct ConversationStateView: View {
    @ObservedObject private var viewModel: ConversationStateViewModel

    init(viewModel: ConversationStateViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        if let activity = viewModel.activity {
            AgentActivityView(activity: activity)
        }
    }
}
