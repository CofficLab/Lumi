import SwiftUI
import LumiCoreKit
import LumiUI
import Foundation

/// 询问用户消息渲染器
///
/// 匹配 ask_user 工具的输出消息，渲染用户选择界面。
/// 当工具返回 __ASK_USER_PENDING__ 标记时触发此渲染器。
public struct AskUserRenderer: SuperMessageRenderer {
    public static let id = "ask-user"
    public static let priority = 95 // 较高优先级，在 ToolOutputRenderer 之前匹配

    public init() {}

    public func canRender(message: ChatMessage) -> Bool {
        // 匹配 ask_user 工具的等待响应消息
        // 工具返回以 __ASK_USER_PENDING__ 或 __ASK_USER_ERROR__ 开头的内容
        message.role == .tool && (
            message.content.hasPrefix("__ASK_USER_PENDING__")
            || message.content.hasPrefix("__ASK_USER_ERROR__")
        )
    }

    @MainActor
    public func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        if message.content.hasPrefix("__ASK_USER_ERROR__") {
            return AnyView(AskUserErrorView(message: message))
        }

        return AnyView(AskUserPendingView(message: message))
    }
}

// MARK: - Pending View (等待用户回答)

/// 等待用户回答的视图
///
/// 显示问题和选项按钮，用户点击后发送回答消息
public struct AskUserPendingView: View {
    let message: ChatMessage

    @State private var responded = false
    @State private var selectedAnswer: String?
    @State private var freeInputText: String = ""

    public var body: some View {
        guard let response = parsePendingResponse(from: message.content) else {
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

        // 发送用户回答消息
        let userMessage = ChatMessage(
            role: .user,
            conversationId: UUID(uuidString: response.conversationId) ?? UUID(),
            content: answer
        )

        // 通过通知系统发送回答
        NotificationCenter.postAskUserResponse(
            toolCallId: response.toolCallId,
            answer: answer,
            conversationId: response.conversationId
        )
    }

    private func optionColor(for option: String, options: [String]) -> Color {
        // 为选项分配不同的颜色
        let colors: [Color] = [
            .adaptive(light: "007AFF", dark: "0A84FF"),  // 蓝
            .adaptive(light: "34C759", dark: "30D158"),  // 绿
            .adaptive(light: "FF3B30", dark: "FF453A"),  // 红
            .adaptive(light: "FF9500", dark: "FF9F0A"),  // 橙
            .adaptive(light: "5856D6", dark: "5E5CE6"),  // 紫
        ]

        let index = options.firstIndex(of: option) ?? 0
        return colors[min(index, colors.count - 1)]
    }

    private func keyboardShortcutForOption(_ option: String, options: [String]) -> KeyboardShortcut? {
        // 为是/否选项分配快捷键
        if option.lowercased().contains("是") || option.lowercased() == "yes" {
            return .init("y", modifiers: .command)
        }
        if option.lowercased().contains("否") || option.lowercased() == "no" {
            return .init("n", modifiers: .command)
        }
        return nil
    }
}

// MARK: - Error View

/// 错误状态视图
public struct AskUserErrorView: View {
    let message: ChatMessage

    public var body: some View {
        guard let errorContent = parseError(from: message.content) else {
            return AnyView(Text("未知错误"))
        }

        return AnyView(
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.adaptive(light: "FF3B30", dark: "FF453A"))
                Text(errorContent.error)
                    .font(.system(size: 13))
                    .foregroundColor(.adaptive(light: "FF3B30", dark: "FF453A"))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.adaptive(light: "FFF5F5", dark: "3A1C1C"))
            )
        )
    }

    private func parseError(from content: String) -> AskUserErrorResponse? {
        guard content.hasPrefix("__ASK_USER_ERROR__\n") else { return nil }
        let jsonString = content.dropFirst("__ASK_USER_ERROR__\n".count)
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AskUserErrorResponse.self, from: jsonData)
    }
}