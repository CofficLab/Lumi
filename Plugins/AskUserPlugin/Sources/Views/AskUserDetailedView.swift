import SwiftUI
import LumiUI
import Foundation
import AgentToolKit
import LumiKernel

/// AskUser 详细模式视图
///
/// 显示问题文本、选项按钮、图标、元信息（toolCallId/conversationId）和自由输入框。
/// 提供最完整的信息和交互选项。
/// 用于 verbosity == .detailed 的情况。
public struct AskUserDetailedView: View {
    let response: AskUserPendingResponse
    let toolCall: ToolCall
    
    @State private var selectedAnswer: String?
    @State private var freeInputText: String = ""
    @State private var responded = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题标题
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text(response.question)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            // 元信息区域
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("ToolCall ID: \(response.toolCallId)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Conversation: \(response.conversationId)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.97))
            )
            
            if responded {
                // 已回答状态
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已回答: \(selectedAnswer ?? freeInputText)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            } else {
                // 待回答状态 - 选项按钮
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
                
                // 分隔线
                Divider()
                    .padding(.vertical, 4)
                
                // 自由输入区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("或者输入自定义回答：")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField("输入回答...", text: $freeInputText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: 0.98))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button {
                            if !freeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                submitAnswer(freeInputText)
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.blue)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(freeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                // 提示文字
                Text("选择预设选项或输入自定义回答")
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
                .stroke(Color.blue.opacity(0.5), lineWidth: 1.5)
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
