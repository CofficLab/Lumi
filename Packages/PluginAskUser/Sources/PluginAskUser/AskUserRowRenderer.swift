import KitAgentTool
import LumiUI
import SwiftUI

/// ask_user 挂起调用的专用行渲染器。
public struct AskUserRowRenderer: ToolCallRowRenderer {
    public static let id = "ask-user-row"
    public static let priority = 100

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        toolCall.name == AskUserTool.toolName
            && toolCall.result?.awaitingUserResponse == true
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let response = try? JSONDecoder().decode(
                AskUserPendingResponse.self,
                from: Data(content.utf8)
              ) else {
            return AnyView(Text("无法解析问题内容"))
        }

        return AnyView(
            AskUserPendingView(
                response: response,
                toolCall: toolCall,
                conversationID: message.conversationId
            )
        )
    }
}

private struct AskUserPendingView: View {
    @LumiTheme private var theme

    let response: AskUserPendingResponse
    let toolCall: ToolCall
    let conversationID: UUID

    @State private var answer = ""
    @State private var responded = false

    private var isFreeText: Bool {
        response.mode == "free_text" || (response.mode == nil && response.options.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(theme.primary)
                Text(response.question)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
            }

            if isFreeText {
                HStack(spacing: 8) {
                    TextField("输入回答…", text: $answer)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(theme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .disabled(responded)

                    submitButton
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(response.options) { option in
                        Button {
                            submit(option.label)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .foregroundColor(theme.textPrimary)
                                    if let description = option.description {
                                        Text(description)
                                            .font(.appMicro)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                                Spacer()
                                if answer == option.label {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.success)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .disabled(responded)
                    }
                }
            }

            if responded {
                Text("已回答：\(answer)")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.primary.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            if let existing = toolCall.result?.interactionState?.answer {
                answer = existing
                responded = true
            }
        }
    }

    private var submitButton: some View {
        Button {
            submit(answer.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
            Image(systemName: "paperplane.fill")
                .padding(8)
                .background(Circle().fill(theme.primary))
                .foregroundColor(theme.textPrimary.isLightColor ? .black : .white)
        }
        .buttonStyle(.plain)
        .disabled(responded || answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submit(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !responded, !value.isEmpty else { return }
        answer = value
        responded = true
        AskUserBridge.shared.resume(
            conversationId: conversationID.uuidString,
            toolCallId: toolCall.id,
            answer: value
        )
    }
}
