import LumiUI
import SwiftUI

/// AskUser 交互视图的无障碍标识符。
///
/// UI 测试（`LumiAskUserUITests`）必须按标识符定位控件，而不是按本地化文案：
/// 问题文案与「已回答」提示都是随 `-AppleLanguages` 变化的文案，按文案定位在
/// 非英文环境下必然失败。选项按钮的 label 恰好是模型产出的稳定常量，可以用文案，
/// 但仍统一加上标识符以便在同一条断言里区分「选项」与「问题」。
///
/// 命名沿用仓库既有惯例（见 `RetryTurnButton.accessibilityIdentifier`）。
enum AskUserAccessibility {
    /// 问题卡片容器。出现即代表有一个挂起中的 ask_user 交互。
    static let card = "lumi.ask-user.card"

    /// 问题正文。
    static let question = "lumi.ask-user.question"

    /// 选项按钮。按下标拼接：`lumi.ask-user.option.0`。
    static func option(index: Int) -> String {
        "lumi.ask-user.option.\(index)"
    }

    /// free_text 模式的回答输入框。
    static let freeTextField = "lumi.ask-user.free-text"

    /// free_text 模式的提交按钮。
    static let submitButton = "lumi.ask-user.submit"

    /// 已回答后的回显（如「已回答：是」）。
    static let answeredLabel = "lumi.ask-user.answered"
}

struct AskUserPendingView: View {
    @LumiTheme private var theme

    let interaction: AskUserPendingInteraction

    @State private var answer = ""
    @State private var responded = false

    private var isFreeText: Bool {
        interaction.response.mode == "free_text"
            || (interaction.response.mode == nil && interaction.response.options.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(theme.primary)
                Text(interaction.response.question)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
                    .accessibilityIdentifier(AskUserAccessibility.question)
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
                        .accessibilityIdentifier(AskUserAccessibility.freeTextField)

                    submitButton
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(interaction.response.options.enumerated()), id: \.element.id) { index, option in
                        Button {
                            submit(option.label)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
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
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let badge = option.badge {
                                        AppTag(badge, systemImage: nil, style: .subtle)
                                            .fixedSize()
                                    }

                                    if answer == option.label {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(theme.success)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .accessibilityElement(children: .combine)
                        .buttonStyle(.plain)
                        .disabled(responded)
                        .accessibilityIdentifier(AskUserAccessibility.option(index: index))
                    }
                }
            }

            if responded {
                Text("已回答：\(answer)")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .accessibilityIdentifier(AskUserAccessibility.answeredLabel)
            }
        }
        .padding(12)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.primary.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier(AskUserAccessibility.card)
        .onAppear {
            if let initialAnswer = interaction.initialAnswer {
                answer = initialAnswer
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
        .accessibilityIdentifier(AskUserAccessibility.submitButton)
    }

    private func submit(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !responded, !value.isEmpty else { return }
        answer = value
        responded = true
        AskUserBridge.shared.resume(
            conversationId: interaction.conversationID.uuidString,
            toolCallId: interaction.toolCallID,
            answer: value
        )
    }
}
