import AgentToolKit
import Foundation
import LumiKernel
import SwiftUI

/// AskUser 简洁模式视图
///
/// 以最小视觉信息呈现问题与作答入口。
/// 用于 verbosity == "brief" 的情况。按 `mode` 分支渲染：
/// - `free_text`: 问题 + 输入框 + 提交按钮
/// - `yes_no` / `choice` / 旧 payload: 问题 + 选项按钮（候选项全部平铺，不再折叠到下拉）
public struct AskUserBriefView: View {
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
    /// 旧 payload（mode==nil）按 options 为空回退，保持与 standard 视图一致的推断。
    private var isFreeText: Bool {
        if let mode = response.mode { return mode == "free_text" }
        return response.options.isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题文本
            Text(response.question)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            if isFreeText {
                freeTextInput
            } else {
                optionsButtons
            }

            if responded {
                Text("已回答：\(selectedAnswer ?? freeInputText)")
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

    /// 选项按钮：是/否 用绿/红高亮，其余候选项平铺为蓝色按钮（不再折叠到「其他」下拉）。
    @ViewBuilder
    private var optionsButtons: some View {
        // 候选项通常不多（2-4 个）；单行排列，SwiftUI 负责布局。
        HStack(spacing: 8) {
            ForEach(response.options) { option in
                optionButton(option)
            }
        }
    }

    @ViewBuilder
    private func optionButton(_ option: AskUserOption) -> some View {
        let color: Color = {
            if option.label == "是" { return .green }
            if option.label == "否" { return .red }
            return .blue
        }()
        Button {
            submitAnswer(option.label)
        } label: {
            VStack(spacing: 2) {
                Text(option.label)
                    .font(.system(size: 13, weight: .medium))
                if let description = option.description {
                    Text(description)
                        .font(.system(size: 10))
                        .opacity(0.9)
                        .lineLimit(1)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
        }
        .buttonStyle(.plain)
        .disabled(responded)
        .opacity(responded && selectedAnswer != option.label ? 0.55 : 1)
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
                        .fill(Color(white: 0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Button {
                let trimmed = freeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { submitAnswer(trimmed) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.blue))
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
