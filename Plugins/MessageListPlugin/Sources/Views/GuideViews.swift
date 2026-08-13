import KernelLumi
import LumiUI
import SwiftUI

/// 未选择对话时的占位视图，提示用户输入消息并回车来创建新对话。
struct NoConversationSelectedView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text(LumiPluginLocalization.string("No conversation selected", bundle: .module))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Type a message and press Enter to start a new conversation.", bundle: .module))
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty state view when the conversation has no messages.
struct MessageEmptyStateView: View {
    @LumiTheme private var theme
    let kernel: KernelLumi

    @State private var apiKey = ""
    @State private var saveError: String?

    private var providerManager: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var provider: (any LumiLLMProvider)? {
        guard let manager = providerManager else { return nil }
        if let selected = manager.selectedProviderID,
           let provider = manager.llmProvider(id: selected) {
            return provider
        }
        return manager.allLLMProviders().first
    }

    private var providerInfo: LumiLLMProviderInfo? {
        provider.map { type(of: $0).info }
    }

    private var hasConfiguredKey: Bool {
        provider?.apiKeyDiagnostic() == .configured
    }

    private let suggestions = [
        "解释这段代码", "帮我写一个脚本", "总结这篇内容", "制定一个执行计划"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasConfiguredKey ? "bubble.left.and.bubble.right" : "key.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.primary.opacity(0.75))

            Text(hasConfiguredKey ? "开始和 Lumi 对话" : "配置 API Key 开始聊天")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            if hasConfiguredKey {
                Text("选择一个示例，或直接在下方输入你的问题。")
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            kernel.conversationInput?.text = suggestion
                            kernel.conversationInput?.isInputFocused = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: 520)
            } else if let providerInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前 Provider：\(providerInfo.displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("聊天请求需要 API Key，请在设置中配置后再开始对话。")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    AppInputField("API Key", text: $apiKey, fieldType: .secure)
                    Button("保存 API Key") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    if let saveError {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(theme.warning)
                    }
                    Link("打开 Provider 官网获取 API Key", destination: providerInfo.websiteURL)
                        .font(.caption)
                }
                .padding(16)
                .frame(maxWidth: 460, alignment: .leading)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(theme.divider, lineWidth: 1) }
            } else {
                Text("还没有可用的 AI Provider，请先在设置中启用一个 Provider。")
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            apiKey = provider?.getApiKey() ?? ""
        }
    }

    private func saveAPIKey() {
        guard let provider else { return }
        do {
            try provider.saveAPIKey(apiKey)
            providerManager?.selectProvider(id: type(of: provider).info.id)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}

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
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…", bundle: .module)))
    }
}

#Preview("Message loading") {
    MessageLoadingView()
        .frame(width: 480, height: 600)
}
