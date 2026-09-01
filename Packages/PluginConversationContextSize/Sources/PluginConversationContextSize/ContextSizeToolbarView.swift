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

    @State private var maxContextSize: Int?
    @State private var usedTokens: Int?
    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?

    @State private var conversationObserver: (any SelectedConversationObserverHandle)?
    @State private var messageObserver: (any MessageInsertedObserverHandle)?
    @State private var llmObserver: (any LLMManagerObserverHandle)?

    var body: some View {
        Group {
            if let maxSize = maxContextSize, maxSize > 0 {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    buttonLabel(maxSize: maxSize)
                }
                .buttonStyle(.plain)
                .help(contextTooltip(used: usedTokens, max: maxSize))
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    ContextSizePopover(used: usedTokens, max: maxSize)
                }
            }
        }
        .task {
            selectedConversationID = conversations.selectedConversationID
            conversationObserver = conversations.addSelectedConversationObserver { newID in
                selectedConversationID = newID
            }
            messageObserver = messages.addMessageInsertedObserver { _, conversationID in
                guard conversationID == conversations.selectedConversationID else { return }
                Task(priority: .utility) { @MainActor in
                    await Task.yield()
                    guard !Task.isCancelled,
                          conversationID == conversations.selectedConversationID else { return }
                    await refreshUsedTokens(for: conversationID)
                }
            }
            llmObserver = llmManager.addObserver { _ in
                Task { @MainActor in
                    guard !Task.isCancelled else { return }
                    await refreshSize(for: selectedConversationID)
                }
            }
        }
        .task(id: selectedConversationID) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            await refreshSize(for: selectedConversationID)
        }
        .onDisappear {
            conversationObserver?.cancel()
            messageObserver?.cancel()
            llmObserver?.cancel()
            conversationObserver = nil
            messageObserver = nil
            llmObserver = nil
        }
    }

    @ViewBuilder
    private func buttonLabel(maxSize: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 10))
            tokenText(maxSize: maxSize)
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
              selectedConversationID == conversationID,
              conversations.selectedConversationID == conversationID else {
            usedTokens = nil
            return
        }
        let allMessages = messages.messages(for: conversationID)
        usedTokens = allMessages.last { $0.inputTokenCount != nil }?.inputTokenCount
    }
}

private func colorForUsage(used: Int?, max: Int) -> Color {
    guard let used, max > 0 else { return .secondary }
    let ratio = Double(used) / Double(max)
    if ratio >= 0.9 { return .red }
    if ratio >= 0.75 { return .orange }
    return .secondary
}

private func contextTooltip(used: Int?, max: Int) -> String {
    if let used, used > 0 {
        return "Context: \(used.formattedTokensShort) / \(max.formattedContextSize) tokens used"
    }
    return "Context window: \(max.formattedContextSize) tokens"
}

private struct ContextSizePopover: View {
    let used: Int?
    let max: Int

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

            Text(max.formattedContextSize)
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()

            if let used, used > 0 {
                Text("\(used.formattedTokensShort) tokens used")
                    .font(.caption)
                    .foregroundColor(.secondary)

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
            } else {
                Text(LumiPluginLocalization.string("No token usage data yet", bundle: .module))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
