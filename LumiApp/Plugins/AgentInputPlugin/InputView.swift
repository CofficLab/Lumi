import AppKit
import MagicKit
import OSLog
import SwiftUI

/// Agent 输入包装视图 - 管理输入区域所需的状态
/// 封装 InputAreaView 并提供模型选择器 popover
///
/// ## 架构说明
/// `PendingMessagesView` 放置在此视图（外层），而不是 `InputAreaView` 内部。
/// 这样设计是为了隔离状态变化：
/// - 当 `pendingMessages` 变化时，只会导致 `PendingMessagesView` 重新渲染
/// - `InputAreaView` 不受影响，输入框保持焦点
struct InputView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentVM

    /// 输入框本地状态 ViewModel（与 agentProvider 解耦，避免每次击键触发全局重庆染）
    @StateObject private var inputViewModel = InputViewModel()

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 模型选择器是否显示
    @State private var isModelSelectorPresented = false

    var body: some View {
        VStack(spacing: 8) {
            // 待发送消息队列（放在外层，避免影响输入框焦点）
            PendingMessagesView(messageSenderViewModel: agentProvider.messageSenderViewModel)

            // 输入区域
            InputAreaView(
                inputViewModel: inputViewModel,
                isInputFocused: $isInputFocused,
                isModelSelectorPresented: $isModelSelectorPresented
            )
        }
        .padding()
        .onAppear(perform: onAppear)
        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
            ModelSelectorView()
        }
    }
}

// MARK: - Actions

// MARK: - Event Handler

extension InputView {
    func onAppear() {
        isInputFocused = true
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    InputView()
        .frame(width: 800, height: 600)
        .inRootView()
}

#Preview("App - Big Screen") {
    InputView()
        .frame(width: 1200, height: 800)
        .inRootView()
}
