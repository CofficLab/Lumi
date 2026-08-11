import LumiKernel
import os
import SuperLogKit
import SwiftUI

/// GoalTaskPlugin 的根视图。
///
/// 支持两种用法:
/// 1. `GoalRootView(viewModel: vm)` —— 仅承载插件根容器(无自定义内容)
/// 2. `GoalRootView(viewModel: vm) { CustomContentView() }` —— 在根容器内嵌入业务视图
///
/// 监听 `onLumiSelectedConversationDidChange`,在切换/清空对话时:
/// - 写入 `viewModel.currentConversationID`
/// - 触发 `viewModel.refresh()` 重新拉取当前对话的 Goal 列表
struct GoalRootView<Content: View>: View, SuperLog {
    public nonisolated static var emoji: String { "🎯" }
    public nonisolated static var verbose: Bool { true }
    public nonisolated static var logger: Logger { GoalTaskPlugin.logger }

    @ObservedObject var viewModel: GoalVM
    private let content: () -> Content

    public init(
        viewModel: GoalVM,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.viewModel = viewModel
        self.content = content
    }

    public var body: some View {
        content()
            .onLumiSelectedConversationDidChange { uuid in
                viewModel.updateCurrentConversationID(uuid)
                Task { await viewModel.refresh() }
            }
    }
}
