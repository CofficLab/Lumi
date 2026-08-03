import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前模型的上下文窗口大小
@MainActor
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

    private func currentContextSize() -> Int? {
        // 在一次 MainActor 快照中读取服务，避免启动注册期间重复解析 service registry。
        guard let providerManager = kernel.llmProvider else { return nil }
        let conversationManager = kernel.conversations
        let conversationID = conversationManager?.selectedConversationID
        let providerID = conversationID.flatMap { conversationManager?.providerID(for: $0) }
            ?? providerManager.selectedProviderID
        let modelName = conversationID.flatMap { conversationManager?.modelName(for: $0) }
            ?? providerManager.selectedModel

        guard let providerID, let modelName else { return nil }
        guard let info = providerManager.providerInfo(id: providerID) else { return nil }
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
