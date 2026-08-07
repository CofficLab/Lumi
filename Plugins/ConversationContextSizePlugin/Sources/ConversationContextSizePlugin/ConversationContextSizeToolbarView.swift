import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前模型的上下文窗口大小
@MainActor
struct ConversationContextSizeToolbarView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 只订阅 conversations + llmProvider 两个 service：上下文窗口大小同时依赖
    // 「当前对话选中的 provider/model」与「provider 注册表」。
    // 不挂在 kernel 全局总线上，project/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var conversationsBox = ObservableConversationsBox()
    @StateObject private var providerBox = ObservableLLMProviderBox()

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // 门控条件依赖 box（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时 bind 永不执行（死锁）。Group 恒存在，保证绑定。
        Group {
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
        .task {
            conversationsBox.bind(kernel.conversations)
            providerBox.bind(kernel.llmProvider)
        }
    }

    private func currentContextSize() -> Int? {
        // 在一次 MainActor 快照中读取服务，避免启动注册期间重复解析 service registry。
        guard let providerManager = providerBox.service else { return nil }
        let conversationManager = conversationsBox.service
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
