import ProviderConversation
import ProviderLLMManager
import ProviderLLMVendors
import ProviderMessage
import SwiftUI

/// 上下文窗口大小工具栏视图。
struct ContextSizeToolbarView: View {
    let conversations: any ConversationManaging
    let messages: any MessageManaging
    let llmManager: any LLMManaging
    @ObservedObject var state: ContextSizeToolbarState

    @State private var maxContextSize: Int?
    @State private var usedTokens: Int?
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            buttonLabel(maxSize: maxContextSize)
        }
        .buttonStyle(.plain)
        .help(contextTooltip(used: usedTokens, max: maxContextSize))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ContextSizePopover(used: usedTokens, max: maxContextSize)
        }
        .task(id: "\(state.selectedConversationID?.uuidString ?? "nil")-\(state.messageRefreshRevision)") {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await refreshSize(for: state.selectedConversationID)
        }
    }

    @ViewBuilder
    private func buttonLabel(maxSize: Int?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 10))
            if let maxSize, maxSize > 0 {
                tokenText(maxSize: maxSize)
            } else {
                Text(LumiPluginLocalization.string("Context: Unknown", bundle: .module))
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundColor(colorForUsage(used: usedTokens, max: maxSize))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Color.secondary.opacity(0.15),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    @ViewBuilder
    private func tokenText(maxSize: Int) -> some View {
        if let used = usedTokens, used > 0 {
            Text("\(used.formattedTokensShort)/\(maxSize.formattedContextSize)")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
        } else {
            Text(maxSize.formattedContextSize)
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
        }
    }

    private func refreshSize(for conversationID: UUID?) async {
        let providerID = conversationID.flatMap { conversations.providerID(for: $0) }
            ?? llmManager.selectedProviderID
            ?? llmManager.allProviders().first?.providerInfo.id

        guard let providerID,
              let provider = llmManager.provider(id: providerID) else {
            maxContextSize = nil
            usedTokens = nil
            return
        }

        let info = provider.providerInfo
        let modelName = conversationID.flatMap { conversations.modelName(for: $0) }
            ?? llmManager.selectedModel
            ?? info.defaultModel

        let modelInfo = info.models.first { $0.id == modelName }
            ?? info.models.first { $0.id == info.defaultModel }
        maxContextSize = modelInfo?.contextWindowSize
        await refreshUsedTokens(for: conversationID)
    }

    private func refreshUsedTokens(for conversationID: UUID?) async {
        guard let conversationID,
              state.selectedConversationID == conversationID,
              conversations.selectedConversationID == conversationID else {
            usedTokens = nil
            return
        }
        let allMessages = await messages.messagesSnapshot(in: conversationID)
        usedTokens = allMessages.last { $0.inputTokenCount != nil }?.inputTokenCount
    }
}

private func colorForUsage(used: Int?, max: Int?) -> Color {
    guard let used, let max, max > 0 else { return .secondary }
    let ratio = Double(used) / Double(max)
    if ratio >= 0.9 { return .red }
    if ratio >= 0.75 { return .orange }
    return .secondary
}

private func contextTooltip(used: Int?, max: Int?) -> String {
    if let max, max > 0, let used, used > 0 {
        return "Context: \(used.formattedTokensShort) / \(max.formattedContextSize) tokens used"
    }
    if let max, max > 0 {
        return "Context window: \(max.formattedContextSize) tokens"
    }
    return LumiPluginLocalization.string("Context window size is unknown", bundle: .module)
}

private struct ContextSizePopover: View {
    let used: Int?
    let max: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(LumiPluginLocalization.string("Context Window", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if let max, max > 0 {
                Text(max.formattedContextSize)
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
            } else {
                Text(LumiPluginLocalization.string("Unknown", bundle: .module))
                    .font(.system(size: 28, weight: .bold))
            }

            if let used, used > 0 {
                Text("\(used.formattedTokensShort) tokens used")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let max, max > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForUsage(used: used, max: max))
                                .frame(width: geo.size.width * min(Double(used) / Double(max), 1.0))
                        }
                    }
                    .frame(height: 6)
                }
            } else {
                if let max, max > 0 {
                    Text(LumiPluginLocalization.string("No token usage data yet", bundle: .module))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(LumiPluginLocalization.string("Context window size is unknown", bundle: .module))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Text("上下文窗口 = 模型单次请求能处理的最大 token 数。输入 + 输出共享此上限。接近上限时可能导致截断或错误。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 280)
    }
}
