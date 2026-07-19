import SwiftUI
import LumiUI
import Foundation
import AgentToolKit
import LumiKernel

/// AskUser 标准模式视图
///
/// 显示问题文本、选项按钮和图标，平衡信息量和视觉简洁度。
/// 用于 verbosity == .standard 的情况。
public struct AskUserStandardView: View {
    let response: AskUserPendingResponse
    let toolCall: ToolCall
    
    @State private var selectedAnswer: String?
    @State private var responded = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题标题
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text(response.question)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            if responded {
                // 已回答状态
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(selectedAnswer ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else {
                // 待回答状态 - 显示所有选项
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(response.options, id: \.self) { option in
                        Button {
                            submitAnswer(option)
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.system(size: 13))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(white: 0.95))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 提示文字
                Text("点击选项回答问题")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func submitAnswer(_ answer: String) {
        selectedAnswer = answer
        responded = true
        
        // 通过 AskUserBridge 提交结果并恢复 Agent 循环
        AskUserBridge.shared.resume(
            conversationId: response.conversationId,
            toolCallId: response.toolCallId,
            answer: answer
        )
    }
}
