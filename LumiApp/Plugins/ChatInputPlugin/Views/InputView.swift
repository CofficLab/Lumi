import AppKit
import MagicKit
import SwiftUI

/// Agent 输入包装视图 - 管理输入区域所需的状态
///
/// 模式切换、模型选择器、发送控制和附件已拆分为独立插件。
/// 本视图仅管理输入编辑器相关状态。
struct InputView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false
    /// 窗口级聊天草稿
    @EnvironmentObject private var chatDraftVM: WindowChatDraftVM

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 是否允许输入/发送（必须先选中会话）
    @EnvironmentObject var WindowConversationVM: WindowConversationVM

    private var canChat: Bool {
        WindowConversationVM.selectedConversationId != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 输入区域（包含编辑器）
            InputAreaView(
                chatDraftVM: chatDraftVM,
                isInputFocused: $isInputFocused
            )
        }
        .onAppear(perform: onAppear)
        // 监听「添加到聊天」事件：将文件选区信息插入输入框
        .onAddToChat { text in
            chatDraftVM.append(text)
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
