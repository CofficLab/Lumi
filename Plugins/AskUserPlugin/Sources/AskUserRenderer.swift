import SwiftUI
import LumiUI
import Foundation
import AgentToolKit

/// AskUser 的 ToolCall 行级渲染器
///
/// 当 `ask_user` 工具处于 `awaitingUserResponse` 状态时，
/// 替代默认的 `ToolCallRow`，渲染用户选择界面。
///
/// 通过 `ToolCallRowRendererRegistry` 注册到 `MessageRendererPlugin`，
/// 无需插件间直接依赖。
public struct AskUserRowRenderer: ToolCallRowRenderer {
    public static let id = "ask-user-row"
    public static let priority = 100

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        toolCall.name == "ask_user"
            && toolCall.result?.awaitingUserResponse == true
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        AnyView(AskUserPendingView(toolCall: toolCall))
    }
}

// MARK: - Pending View (等待用户回答)

/// 等待用户回答的视图
///
/// 显示问题和选项按钮，用户点击后通过 AskUserBridge 提交结果并恢复 Agent 循环。
public struct AskUserPendingView: View {
    let toolCall: ToolCall

    @State private var responded = false
    @State private var selectedAnswer: String?
    @State private var freeInputText: String = ""

    public var body: some View {
        guard let response = parsePendingResponse(from: toolCall.result?.content ?? "") else {
            return AnyView(Text("无法解析问题内容"))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                // 问题标题
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.adaptive(light: "007AFF", dark: "0A84FF"))
                    Text(response.question)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                if responded {
                    // 已回答状态
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.adaptive(light: "34C759", dark: "30D158"))
                        Text("用户选择: \(selectedAnswer ?? freeInputText)")
                            .font(.system(size: 13))
                            .foregroundColor(.adaptive(light: "34C759", dark: "30D158"))
                    }
                } else {
                    // 待回答状态 - 显示选项
                    if response.allowFreeInput {
                        // 自由输入模式
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(response.options, id: \.self) { option in
                                Button {
                                    submitAnswer(option, response: response)
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
                                            .fill(Color.adaptive(light: "F2F2F7", dark: "1C1C1E"))
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            // 自由输入框
                            HStack(spacing: 8) {
                                TextField("输入其他回答...", text: $freeInputText)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.adaptive(light: "F2F2F7", dark: "1C1C1E"))
                                    )

                                Button {
                                    if !freeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        submitAnswer(freeInputText, response: response)
                                    }
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.adaptive(light: "007AFF", dark: "0A84FF"))
                                }
                                .buttonStyle(.plain)
                                .disabled(freeInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    } else {
                        // 仅选项模式
                        HStack(spacing: 8) {
                            ForEach(response.options, id: \.self) { option in
                                Button {
                                    submitAnswer(option, response: response)
                                } label: {
                                    Text(option)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(optionColor(for: option, options: response.options))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 提示文字
                    Text("等待您的选择...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.adaptive(light: "FFFFFF", dark: "2C2C2E"))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        responded
                            ? Color.adaptive(light: "34C759", dark: "30D158")
                            : Color.adaptive(light: "007AFF", dark: "0A84FF"),
                        lineWidth: 1
                    )
            )
        )
    }

    private func parsePendingResponse(from content: String) -> AskUserPendingResponse? {
        guard content.hasPrefix("__ASK_USER_PENDING__\n") else { return nil }
        let jsonString = content.dropFirst("__ASK_USER_PENDING__\n".count)
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AskUserPendingResponse.self, from: jsonData)
    }

    private func submitAnswer(_ answer: String, response: AskUserPendingResponse) {
        selectedAnswer = answer
        responded = true

        // 通过 AskUserBridge 提交结果并恢复 Agent 循环
        AskUserBridge.shared.resume(
            conversationId: response.conversationId,
            toolCallId: response.toolCallId,
            answer: answer
        )
    }

    private func optionColor(for option: String, options: [String]) -> Color {
        let colors: [Color] = [
            .adaptive(light: "007AFF", dark: "0A84FF"),
            .adaptive(light: "34C759", dark: "30D158"),
            .adaptive(light: "FF3B30", dark: "FF453A"),
            .adaptive(light: "FF9500", dark: "FF9F0A"),
            .adaptive(light: "5856D6", dark: "5E5CE6"),
        ]
        let index = options.firstIndex(of: option) ?? 0
        return colors[min(index, colors.count - 1)]
    }
}
