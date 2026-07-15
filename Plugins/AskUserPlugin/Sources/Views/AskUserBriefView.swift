import SwiftUI
import LumiUI
import Foundation
import AgentToolKit
import LumiCoreKit

/// AskUser 简洁模式视图
///
/// 仅显示问题文本和是/否按钮，最小化视觉信息。
/// 用于 verbosity == .brief 的情况。
public struct AskUserBriefView: View {
    let response: AskUserPendingResponse
    let toolCall: ToolCall
    
    @State private var selectedAnswer: String?
    @State private var responded = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题文本
            Text(response.question)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
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
                // 待回答状态 - 仅显示是/否按钮
                HStack(spacing: 8) {
                    if response.options.contains("是") {
                        Button {
                            submitAnswer("是")
                        } label: {
                            Text("是")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.green)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if response.options.contains("否") {
                        Button {
                            submitAnswer("否")
                        } label: {
                            Text("否")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 如果有其他选项，显示下拉选择
                    let otherOptions = response.options.filter { $0 != "是" && $0 != "否" }
                    if !otherOptions.isEmpty {
                        Menu {
                            ForEach(otherOptions, id: \.self) { option in
                                Button(option) {
                                    submitAnswer(option)
                                }
                            }
                        } label: {
                            Text("其他")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue)
                                )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.98))
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
