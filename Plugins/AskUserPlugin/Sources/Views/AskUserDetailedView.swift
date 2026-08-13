import AgentToolKit
import Foundation
import KernelLumi
import LumiUI
import SwiftUI

/// AskUser 详细模式视图
public struct AskUserDetailedView: View {
    @LumiTheme private var theme

    let response: AskUserPendingResponse
    let toolCall: ToolCall

    @State private var selectedAnswer: String?
    @State private var freeInputText: String = ""
    @State private var responded = false

    public init(response: AskUserPendingResponse, toolCall: ToolCall) {
        self.response = response
        self.toolCall = toolCall
        let answer = toolCall.result?.interactionState?.answer
        _selectedAnswer = State(initialValue: answer)
        _freeInputText = State(initialValue: answer ?? "")
        _responded = State(initialValue: answer != nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.primary)
                Text(response.question)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                    Text("ToolCall ID: \(response.toolCallId)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                    Text("Conversation: \(response.conversationId)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.elevatedSurface)
            )

            // 选项始终保留；回答后仅禁用。
            VStack(alignment: .leading, spacing: 8) {
                ForEach(response.options) { option in
                    AskUserOptionRow(
                        option: option,
                        selectedAnswer: selectedAnswer,
                        responded: responded,
                        onSelect: submitAnswer
                    )
                }
            }

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("或者输入自定义回答：")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)

                HStack(spacing: 8) {
                    TextField("输入回答...", text: $freeInputText)
                        .textFieldStyle(.plain)
                        .disabled(responded)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.elevatedSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.divider, lineWidth: 1)
                        )

                    Button {
                        if !freeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            submitAnswer(freeInputText)
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textPrimary.isLightColor ? .black : .white)
                            .padding(8)
                            .background(Circle().fill(theme.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(responded || freeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Text(responded ? "已回答：\(selectedAnswer ?? freeInputText)" : "选择预设选项或输入自定义回答")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.primary.opacity(0.5), lineWidth: 1.5)
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
