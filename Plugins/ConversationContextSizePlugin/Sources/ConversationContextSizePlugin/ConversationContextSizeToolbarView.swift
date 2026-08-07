import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前模型的上下文窗口大小
@MainActor
struct ConversationContextSizeToolbarView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 上下文窗口大小同时依赖「当前对话选中的 provider/model」（随会话切换变化，
    // 由 .onLumiSelectedConversationDidChange 事件驱动）与「provider 注册表」
    // （provider 选择变化由 provider 事件驱动）。size 缓存进 @State。
    // 不挂 kernel 全局总线。
    @State private var size: Int?

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // 门控条件依赖 size（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时初始化永不执行（死锁）。Group 恒存在，保证初始化。
        Group {
            if let size, size > 0 {
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
        .task { refreshSize() }
        .onLumiSelectedConversationDidChange { refreshSize() }
        .onLumiSelectedRemoteProviderIDDidChange { refreshSize() }
        .onLumiSelectedLocalProviderIDDidChange { refreshSize() }
        .onLumiSelectedModelsDidChange { refreshSize() }
    }

    private func refreshSize() {
        // 在一次 MainActor 快照中读取服务，避免启动注册期间重复解析 service registry。
        guard let providerManager = kernel.llmProvider else {
            size = nil
            return
        }
        let conversationManager = kernel.conversations
        let conversationID = conversationManager?.selectedConversationID
        let providerID = conversationID.flatMap { conversationManager?.providerID(for: $0) }
            ?? providerManager.selectedProviderID
        let modelName = conversationID.flatMap { conversationManager?.modelName(for: $0) }
            ?? providerManager.selectedModel

        guard let providerID, let modelName,
              let info = providerManager.providerInfo(id: providerID) else {
            size = nil
            return
        }
        size = info.contextWindowSizes[modelName]
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
