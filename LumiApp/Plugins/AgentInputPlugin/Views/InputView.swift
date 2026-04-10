import AppKit
import MagicKit
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

    /// 输入框本地状态 ViewModel（与全局环境解耦，避免每次击键触发全局重渲染）
    @StateObject private var inputViewModel = InputViewModel()

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 模型选择器是否显示
    @State private var isModelSelectorPresented = false

    /// 是否允许输入/发送（必须先选中会话）
    @EnvironmentObject var ConversationVM: ConversationVM

    private var canChat: Bool {
        ConversationVM.selectedConversationId != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // 待发送消息队列
            PendingMessagesView()

            // 输入区域（包含编辑器、工具栏）
            InputAreaView(
                inputViewModel: inputViewModel,
                isInputFocused: $isInputFocused,
                isModelSelectorPresented: $isModelSelectorPresented
            )

            // 快捷输入视图（仅在有项目选中时显示）
            QuickInputView(inputViewModel: inputViewModel)
                .padding(.horizontal, 8)
                .allowsHitTesting(canChat)
                .opacity(canChat ? 1 : 0.6)
        }
        .onAppear(perform: onAppear)
        .popover(isPresented: $isModelSelectorPresented, arrowEdge: .bottom) {
            ModelSelectorView()
        }
        // 监听「添加到聊天」事件：将文件选区信息插入输入框
        .onAddToChat { text in
            inputViewModel.append(text)
            isInputFocused = true
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
