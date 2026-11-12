import Foundation
import KitAgentTool
import LumiUI
import SwiftUI

/// Computer Use 授权卡片的无障碍标识符。
///
/// UI 测试必须按标识符定位按钮：按钮文案是随 `-AppleLanguages` 变化的
/// 本地化文本，按文案定位在非英文环境下必然失败。
enum ComputerUseAuthorizationAccessibility {
    static let card = "lumi.computer-use-authorization.card"
    static let question = "lumi.computer-use-authorization.question"
    static let application = "lumi.computer-use-authorization.application"
    static func button(_ decision: ComputerUseAuthorizationDecision) -> String {
        "lumi.computer-use-authorization.\(decision.rawValue)"
    }
}

/// Computer Use 授权卡片视图。
///
/// 展示目标应用与即将执行的操作，提供「本任务内允许 / 拒绝」两个决定。
struct ComputerUseAuthorizationCard: View {
    @LumiTheme private var theme

    let request: ComputerUseAuthorizationRequest
    let toolCall: ToolCall
    let conversationID: UUID

    @State private var responded = false

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 10,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            showShadow: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                header

                Text(request.operation)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)

                buttons

                if responded {
                    Text(pluginLocalization.string("Submitted: waiting to continue…"))
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        // - Important: 必须显式 `children: .contain`。否则 SwiftUI 会把卡片当作
        //   一个整体元素，把容器上的 identifier 覆盖到所有后代，子元素最终统统
        //   报告同一个 id，UI 测试无法按标识符区分三个按钮
        //   （与 `ToolApprovalPendingView` 同一坑）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.card)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.square.fill")
                .foregroundColor(theme.primary)
            Text(
                pluginLocalization
                    .string("Lumi wants to use {app}")
                    .replacingOccurrences(of: "{app}", with: request.applicationName)
            )
            .font(.appCaption)
            .foregroundColor(theme.textPrimary)
            .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.question)

            Spacer(minLength: 0)

            Text(request.bundleIdentifier)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.application)
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            ForEach(ComputerUseAuthorizationDecision.allCases, id: \.self) { decision in
                AppButton(
                    decision.displayTitle,
                    systemImage: decision.systemImage,
                    style: buttonStyle(for: decision),
                    size: .small,
                    fillsWidth: true
                ) {
                    submit(decision)
                }
                .disabled(responded)
                .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.button(decision))
            }
        }
    }

    private func buttonStyle(for decision: ComputerUseAuthorizationDecision) -> AppButton.Style {
        switch decision {
        case .allowForTask: return .primary
        case .deny: return .destructive
        }
    }

    /// 把决策交给桥接层落地：写入授权存储 → 恢复挂起的回合。
    private func submit(_ decision: ComputerUseAuthorizationDecision) {
        guard !responded else { return }
        responded = true
        ComputerUseAuthorizationBridge.shared.resolve(
            conversationID: conversationID,
            toolCall: toolCall,
            request: request,
            decision: decision
        )
    }
}
