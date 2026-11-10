import CoreGraphics
import Foundation
import LumiLocalizationKit
import LumiUI
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V5（ChatGPT）轮尾操作栏。
///
/// 基准是 V5 方案第 2.5 节：
/// - 一轮可有多个 assistant/tool 行，但轮尾操作**只出现一次**；
/// - 最新已完成 assistant 的复制操作**常驻**；
///   历史 turn 在 hover 或键盘 focus 时出现；
/// - 运行中不显示复制成功态或伪 retry；
/// - 成功回复**不**显示「重新生成」。
///
/// - Important: 复制使用**整轮**文本（`context.assistantCopyText`），
///   而不是只有最后一行。
struct ChatGPTMessageActionsView: View {
    @LumiTheme private var theme

    /// 本轮是否仍在运行中。
    let isRunning: Bool
    /// 整轮复制文本；为空时没有复制按钮。
    let copyText: String
    /// 本轮是否处于 hover / 键盘 focus。
    let isActive: Bool

    @State private var copyState = ChatGPTCopyFeedbackState()

    /// 是否显示复制按钮。
    private var showsCopyButton: Bool {
        ChatGPTAssistantTextStyle.shouldShowCopyButton(copyText: copyText)
    }

    /// 操作栏是否可见。
    ///
    /// - Important: **运行中不显示** —— 流式期间复制的是半截正文。
    /// - Important: 最新一轮（常驻）不依赖 hover；历史轮依赖 hover。
    private var isVisible: Bool {
        guard !isRunning else { return false }
        guard showsCopyButton else { return false }
        return isActive
    }

    var body: some View {
        if showsCopyButton {
            HStack(spacing: 4) {
                copyButton
            }
            .frame(
                minHeight: ChatGPTAssistantTextStyle.actionBarSlotHeight,
                alignment: .leading
            )
            .opacity(isVisible ? 1 : 0)
            .animation(
                .easeOut(duration: ChatGPTAssistantTextStyle.actionBarFadeDuration),
                value: isVisible
            )
            // Important: 透明时**不能**用 `hidden()` —— 那会把按钮从 AX 树里摘掉。
            .accessibilityElement(children: .contain)
        }
    }

    private var copyButton: some View {
        Button {
            LumiPasteboard.copyString(copyText)
            copyState.markCopied()
        } label: {
            Image(systemName: copyState.isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .frame(
                    width: ChatGPTAssistantTextStyle.actionButtonSize,
                    height: ChatGPTAssistantTextStyle.actionButtonSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.turnCopyButton)
        .accessibilityLabel(pluginLocalization.string("Copy"))
        .help(pluginLocalization.string("Copy"))
    }
}
