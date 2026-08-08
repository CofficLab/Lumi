import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前模型的上下文窗口大小和使用量
@MainActor
struct ConversationContextSizeToolbarView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 上下文窗口大小同时依赖「当前对话选中的 provider/model」（随会话切换变化，
    // 由 .onLumiSelectedConversationDidChange 事件驱动）与「provider 注册表」
    // （provider 选择变化由 provider 事件驱动）。size 缓存进 @State。
    // 不挂 kernel 全局总线。
    @State private var maxContextSize: Int?
    /// 当前对话最后一条消息的 inputTokens（代表本次请求的上下文消耗）。
    @State private var usedTokens: Int?
    @State private var isPopoverPresented = false

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // 门控条件依赖 maxContextSize（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时初始化永不执行（死锁）。Group 恒存在，保证初始化。
        Group {
            if let maxSize = maxContextSize, maxSize > 0 {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 11))
                        if let used = usedTokens, used > 0 {
                            Text("\(Self.formatTokens(used))/\(Self.formatContextSize(maxSize))")
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                        } else {
                            Text(Self.formatContextSize(maxSize))
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                        }
                    }
                    .foregroundColor(Self.tokensColor(used: usedTokens, max: maxSize))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.surface.opacity(0.5))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(Self.buildTooltip(used: usedTokens, max: maxSize))
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    ContextSizePopover(used: usedTokens, max: maxSize)
                }
            }
        }
        .task { await refreshSize() }
        .onLumiSelectedConversationDidChange { Task { await self.refreshSize() } }
        .onLumiSelectedRemoteProviderIDDidChange { Task { await self.refreshSize() } }
        .onLumiSelectedLocalProviderIDDidChange { Task { await self.refreshSize() } }
        .onLumiSelectedModelsDidChange { Task { await self.refreshSize() } }
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { notification in
            Task { @MainActor in
                if let conversationID = notification.lumiConversationID,
                   conversationID == kernel.conversations?.selectedConversationID {
                    await refreshUsedTokens()
                }
            }
        }
    }

    private func refreshSize() async {
        // 在一次 MainActor 快照中读取服务，避免启动注册期间重复解析 service registry。
        guard let providerManager = kernel.llmProvider else {
            maxContextSize = nil
            usedTokens = nil
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
            maxContextSize = nil
            usedTokens = nil
            return
        }
        maxContextSize = info.modelInfo(for: modelName)?.contextWindowSize
        await refreshUsedTokens()
    }

    /// 从 MessageManager 获取当前对话最后一条 assistant 消息的 inputTokens。
    private func refreshUsedTokens() async {
        guard let conversationID = kernel.conversations?.selectedConversationID,
              let messageManager = kernel.resolveService((any MessageManaging).self) else {
            usedTokens = nil
            return
        }

        // 取该会话的所有消息（非分页），返回按时间升序。
        let messages = messageManager.messages(for: conversationID)

        // 找最后一个有 inputTokenCount 的消息（通常是 assistant 回复，它记录了本次请求的 inputTokens）。
        // 用户消息没有 inputTokenCount（那是模型的请求），所以取最后一条有值的。
        let lastMessageWithTokens = messages.last { $0.inputTokenCount != nil }
        usedTokens = lastMessageWithTokens?.inputTokenCount
    }

    /// 格式化 token 数量：1000 → "1K"，1500 → "2K"
    private static func formatTokens(_ tokens: Int) -> String {
        let k = (tokens + 999) / 1000  // 向上取整到 K
        return "\(k)K"
    }

    /// 格式化上下文大小：128000 → "128K"
    private static func formatContextSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M"
            }
            return String(format: "%.1fM", m)
        }
        let k = tokens / 1_000
        return "\(k)K"
    }

    /// 根据已用/最大比例返回颜色：接近上限时变红。
    private static func tokensColor(used: Int?, max: Int) -> Color {
        guard let used, max > 0 else { return .secondary }
        let ratio = Double(used) / Double(max)
        if ratio >= 0.9 {
            return .red
        } else if ratio >= 0.75 {
            return .orange
        }
        return .secondary
    }

    private static func buildTooltip(used: Int?, max: Int) -> String {
        if let used, used > 0 {
            let usedFormatted = Self.formatContextSizeDetail(used)
            let maxFormatted = Self.formatContextSizeDetail(max)
            return "Context: \(usedFormatted) / \(maxFormatted)"
        }
        return "Context window: \(Self.formatContextSizeDetail(max))"
    }

    private static func formatContextSizeDetail(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M tokens"
            }
            return String(format: "%.1fM tokens", m)
        }
        let k = tokens / 1_000
        return "\(k)K tokens"
    }
}

// MARK: - ContextSizePopover

private struct ContextSizePopover: View {
    let used: Int?
    let max: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LumiPluginLocalization.string("Context Window", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                explanationRow(
                    icon: "brain",
                    text: LumiPluginLocalization.string("Maximum tokens the model can process in a single request.", bundle: .module)
                )
                explanationRow(
                    icon: "arrow.left.arrow.right",
                    text: LumiPluginLocalization.string("Includes both input (messages) and output (response).", bundle: .module)
                )
                explanationRow(
                    icon: "chart.bar",
                    text: LumiPluginLocalization.string("Larger context allows more conversation history to be sent.", bundle: .module)
                )
                explanationRow(
                    icon: "exclamationmark.triangle",
                    text: LumiPluginLocalization.string("When nearing the limit, older messages may be truncated.", bundle: .module)
                )
            }

            Divider()

            // Used tokens row (if available)
            if let used, used > 0 {
                HStack {
                    Text(LumiPluginLocalization.string("Last request:", bundle: .module))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(Self.formatTokens(used))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
            }

            // Max tokens row
            HStack {
                Text(LumiPluginLocalization.string("Model limit:", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(Self.formatContextSizeDetail(max))
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(10)
        .frame(width: 260)
    }

    private func explanationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
        }
    }

    private static func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M tokens"
            }
            return String(format: "%.1fM tokens", m)
        }
        let k = tokens / 1_000
        return "\(k)K tokens"
    }

    private static func formatContextSizeDetail(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M tokens"
            }
            return String(format: "%.1fM tokens", m)
        }
        let k = tokens / 1_000
        return "\(k)K tokens"
    }
}
