import AgentToolKit
import Foundation
import LumiKernel
import SwiftUI

/// AskUser 标准模式视图
///
/// 显示问题文本、选项按钮和图标，平衡信息量和视觉简洁度。
/// 用于 verbosity == "standard" 的情况。
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

            // 选项始终保留；回答后仅禁用，避免用户误以为问题消失。
            VStack(alignment: .leading, spacing: 8) {
                ForEach(response.options, id: \.self) { option in
                    Button {
                        submitAnswer(option)
                    } label: {
                        HStack {
                            Text(option)
                                .font(.system(size: 13))
                            Spacer()
                            Image(systemName: selectedAnswer == option ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(selectedAnswer == option ? .green : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedAnswer == option ? Color.green.opacity(0.12) : Color(white: 0.95))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(responded)
                    .opacity(responded && selectedAnswer != option ? 0.55 : 1)
                }
            }

            if responded {
                Text("已回答：\(selectedAnswer ?? "")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
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
