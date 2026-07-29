import AgentToolKit
import Foundation
import LumiKernel
import SwiftUI

/// AskUser 简洁模式视图
///
/// 仅显示问题文本和是/否按钮，最小化视觉信息。
/// 用于 verbosity == "brief" 的情况。
public struct AskUserBriefView: View {
    let response: AskUserPendingResponse
    let toolCall: ToolCall

    @State private var selectedAnswer: String?
    @State private var responded = false

    public init(response: AskUserPendingResponse, toolCall: ToolCall) {
        self.response = response
        self.toolCall = toolCall
        let answer = toolCall.result?.interactionState?.answer
        _selectedAnswer = State(initialValue: answer)
        _responded = State(initialValue: answer != nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题文本
            Text(response.question)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            // 选项始终保留；回答后仅禁用。
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
                        .disabled(responded)
                        .opacity(responded && selectedAnswer != "是" ? 0.55 : 1)
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
                        .disabled(responded)
                        .opacity(responded && selectedAnswer != "否" ? 0.55 : 1)
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
                        .disabled(responded)
                        .opacity(responded ? 0.55 : 1)
                    }
                }

            if responded {
                Text("已回答：\(selectedAnswer ?? "")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.98))
        )
    }

    private func submitAnswer(_ answer: String) {
        guard !responded else { return }
        selectedAnswer = answer
        responded = true

        AskUserBridge.shared.resume(
            conversationId: response.conversationId,
            toolCallId: response.toolCallId,
            answer: answer
        )
    }
}
