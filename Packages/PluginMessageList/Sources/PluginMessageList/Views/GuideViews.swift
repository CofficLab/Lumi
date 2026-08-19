import LumiUI
import ProviderMessageSender
import ProviderPromptSuggestion
import SwiftUI

/// Loading state view shown while the message list is fetching data.
///
/// Renders a single SF Symbol with a gentle breathing (opacity) animation
/// so the user perceives the app as "alive" without visual noise.
struct MessageLoadingView: View {
    @LumiTheme private var theme

    /// Drives the breathing opacity animation.
    @State private var isBreathing = false

    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right")
            .font(.largeTitle)
            .foregroundStyle(theme.textSecondary)
            .opacity(isBreathing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear { isBreathing = true }
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…")))
    }
}

/// Empty state view when the conversation has no messages.
///
/// 显示图标 + 标题 + 副标题 + 推荐提示词芯片。
/// 点击提示词会直接发送对应消息。
struct MessageEmptyStateView: View {
    @LumiTheme private var theme
    let services: MessageListServices

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.primary.opacity(0.75))

            Text(LumiPluginLocalization.string("Start chatting with Lumi"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Pick an example, or type your question below."))
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            // 推荐提示词芯片
            if let promptSuggestions = services.promptSuggestions,
               !promptSuggestions.allSuggestions.isEmpty {
                PromptSuggestionFlow(suggestions: promptSuggestions.allSuggestions, services: services)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 未选择对话时的占位视图。
///
/// 显示图标 + 通用问候语 + 推荐提示词芯片。
struct NoConversationSelectedView: View {
    @LumiTheme private var theme
    let services: MessageListServices

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text(LumiPluginLocalization.string("How can I help you today?"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            // 推荐提示词芯片
            if let promptSuggestions = services.promptSuggestions,
               !promptSuggestions.allSuggestions.isEmpty {
                PromptSuggestionFlow(suggestions: promptSuggestions.allSuggestions, services: services)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Prompt Suggestion Components

/// 提示词芯片流式布局容器。
private struct PromptSuggestionFlow: View {
    let suggestions: [PromptSuggestion]
    let services: MessageListServices

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(suggestions.sorted(by: { $0.order < $1.order }), id: \.id) { suggestion in
                PromptSuggestionButton(suggestion: suggestion, services: services)
            }
        }
        .frame(maxWidth: 480)
    }
}

/// 提示词胶囊按钮：点击发送该提示词。
private struct PromptSuggestionButton: View {
    let suggestion: PromptSuggestion
    let services: MessageListServices

    var body: some View {
        Button {
            handlePromptSuggestionTap(suggestion, services: services)
        } label: {
            PromptSuggestionChip(title: suggestion.title)
        }
        .buttonStyle(.plain)
    }
}

/// 处理提示词点击：发送消息。
@MainActor
private func handlePromptSuggestionTap(_ suggestion: PromptSuggestion, services: MessageListServices) {
    guard let sender = services.sender else { return }
    Task {
        try? await sender.sendMessage(suggestion.prompt, conversationID: nil)
    }
}

/// 提示词胶囊芯片样式。
///
/// 镜像 `LumiUI.AppTag` 的强调风格（主题色玻璃底 + 悬停放大/高亮）。
private struct PromptSuggestionChip: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    private let title: String

    @State private var isHovered = false

    init(title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.appCaption)
                .lineLimit(1)
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(isHovered ? theme.primary.opacity(0.22) : theme.primary.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    isHovered ? theme.primary.opacity(0.40) : theme.primary.opacity(0.22),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered && motionPreference.allowsMotion ? LumiMotion.hoverScale : 1.0)
        .shadow(color: theme.primary.opacity(isHovered ? 0.20 : 0), radius: isHovered ? 8 : 0, y: isHovered ? 3 : 0)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovered)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
    }
}

/// 流式布局：自动换行的子视图排列。
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > maxWidth {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += (x == 0 ? 0 : spacing) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(x, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
