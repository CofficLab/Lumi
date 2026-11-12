import Foundation
import KitAgentTool
import LumiUI
import SwiftUI

struct ToolApprovalPendingView: View {
    @LumiTheme private var theme

    let request: ToolPermissionRequest
    let toolCall: ToolCall
    let conversationID: UUID

    @State private var responded = false

    private var options: [String] {
        guard !request.options.contains(where: { ToolApprovalAction(answer: $0) == .alwaysAllow }) else {
            return request.options
        }

        var options = request.options
        let insertionIndex = options.firstIndex {
            ToolApprovalAction(answer: $0) == .reject
        } ?? options.endIndex
        options.insert(ToolApprovalAction.alwaysAllowLabel, at: insertionIndex)
        return options
    }

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 10,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            showShadow: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(theme.primary)
                    Text(request.question)
                        .font(.appCaption)
                        .foregroundColor(theme.textPrimary)
                        .accessibilityIdentifier(ToolApprovalAccessibility.question)
                }

                HStack(spacing: 8) {
                    ForEach(options.indices, id: \.self) { index in
                        let option = options[index]
                        let action = ToolApprovalAction(answer: option)
                        AppButton(
                            option,
                            systemImage: action.systemImage,
                            style: action.buttonStyle,
                            size: .small,
                            fillsWidth: true
                        ) {
                            submit(option)
                        }
                        .disabled(responded)
                        .accessibilityIdentifier(action.accessibilityIdentifier)
                    }
                }

                if responded {
                    Text("已提交：等待继续执行…")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        // - Important: 必须显式 `children: .contain`。否则 SwiftUI 会把卡片
        //   当作一个整体元素，把容器上的 `accessibilityIdentifier` 覆盖到所有后代，
        //   子元素最终统统报告同一个 id，UI 测试无法按标识符区分
        //   「允许 / 始终允许 / 拒绝」（与 `AskUserPendingView` 同一坑）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ToolApprovalAccessibility.card)
    }

    private func submit(_ answer: String) {
        guard !responded else { return }
        responded = true
        ToolApprovalBridge.shared.resolve(
            conversationID: conversationID,
            toolCall: toolCall,
            answer: answer
        )
    }
}
