import LumiUI
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
/// 新版精简版：保留旧版的图标 + 标题 + 副标题视觉。旧版额外的提示词胶囊
/// （`PromptSuggestionButton`）、API Key 内联配置与「添加项目」选择器依赖旧内核
/// 的 `PromptSuggestionProviding` / `LLMProviderManaging` / `ProjectProviding` 类型，
/// 属于宿主与其他插件的职责；新版宿主若提供等价 Provider，可在此处增量补回。
struct MessageEmptyStateView: View {
    @LumiTheme private var theme

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
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 未选择对话时的占位视图。
///
/// 新版精简版：保留旧版的图标 + 通用问候语视觉。旧版的项目名下拉菜单与
/// 「添加项目」选择器依赖旧内核的 `ProjectProviding`，属于宿主职责；
/// 新版宿主注入对应 Provider 后可增量补回。
struct NoConversationSelectedView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text(LumiPluginLocalization.string("How can I help you today?"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
