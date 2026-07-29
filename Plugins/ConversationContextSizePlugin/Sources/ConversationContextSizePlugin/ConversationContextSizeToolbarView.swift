import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前模型的上下文窗口大小
struct ConversationContextSizeToolbarView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        if let size = currentContextSize(), size > 0 {
            HStack(spacing: 4) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 11))
                Text(Self.formatContextSize(size))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.surface.opacity(0.5))
            )
            .help("Context window: \(size.formatted()) tokens")
        }
    }

    private var llmProviderManager: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private func currentContextSize() -> Int? {
        // 优先从当前对话获取 provider/model
        let conversations = kernel.conversations
        let conversationID = conversations?.selectedConversationID
        let providerID = conversationID.flatMap { conversations?.providerID(for: $0) }
            ?? llmProviderManager?.selectedProviderID
        let modelName = conversationID.flatMap { conversations?.modelName(for: $0) }
            ?? llmProviderManager?.selectedModel

        guard let providerID, let modelName else { return nil }
        guard let info = llmProviderManager?.providerInfo(id: providerID) else { return nil }
        return info.contextWindowSizes[modelName]
    }

    /// 格式化上下文大小：128000 → "128K"
    private static func formatContextSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M ctx"
            }
            return String(format: "%.1fM ctx", m)
        }
        let k = tokens / 1_000
        return "\(k)K ctx"
    }
}
