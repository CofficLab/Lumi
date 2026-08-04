import AgentToolKit
import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// AskUser 标准模式视图
///
/// 显示问题文本、选项按钮和图标，平衡信息量和视觉简洁度。
/// 用于 verbosity == "standard" 的情况。
public struct AskUserStandardView: View {
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

    /// 是否按自由输入渲染。`mode` 显式为 free_text 时为真；
    /// 旧 payload（mode==nil）下按 options 为空回退，保持旧行为。
    private var isFreeText: Bool {
        if let mode = response.mode { return mode == "free_text" }
        return response.options.isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题标题
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.primary)
                Text(response.question)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }

            if isFreeText {
                freeTextInput
            } else {
                optionsList
            }

            if responded {
                Text("已回答：\(selectedAnswer ?? freeInputText)")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            } else {
                Text(isFreeText ? "输入回答后提交" : "点击选项回答问题")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.primary.opacity(0.3), lineWidth: 1)
        )
    }

    /// 选项列表；回答后仅禁用，避免用户误以为问题消失。
    private var optionsList: some View {
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
    }

    /// 自由输入行（mode == free_text）。
    private var freeTextInput: some View {
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
                let trimmed = freeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { submitAnswer(trimmed) }
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
