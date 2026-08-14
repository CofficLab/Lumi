import KernelLumi
import LumiUI
import SwiftUI

/// 工具栏视图：显示当前模型的上下文窗口大小和使用量
@MainActor
struct ToolbarView: View {
    @LumiTheme private var theme
    let kernel: KernelLumi

    @State private var maxContextSize: Int?
    @State private var usedTokens: Int?
    @State private var isPopoverPresented = false

    var body: some View {
        Group {
            if let maxSize = maxContextSize, maxSize > 0 {
                Button {
                    isPopoverPresented.toggle()
                } label: {
                    buttonLabel(maxSize: maxSize)
                }
                .buttonStyle(.plain)
                .help(String.contextTooltip(used: usedTokens, max: maxSize))
                .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
                    Popover(used: usedTokens, max: maxSize)
                }
            }
        }
        .task { await refreshSize() }
        .onLumiConversationDidCreate { _ in Task { await self.refreshSize() } }
        .onLumiSelectedConversationDidChange { Task { await self.refreshSize() } }
        .onLumiSelectedRemoteProviderIDDidChange { Task { await self.refreshSize() } }
        .onLumiSelectedLocalProviderIDDidChange { Task { await self.refreshSize() } }
        .onLumiSelectedModelsDidChange { Task { await self.refreshSize() } }
        .onLumiLLMProvidersDidChange { Task { await self.refreshSize() } }
        .onLumiMessagesDidChange { eventConversationID in
            if eventConversationID == kernel.conversations?.selectedConversationID {
                Task { await self.refreshUsedTokens() }
            }
        }
    }

    @ViewBuilder
    private func buttonLabel(maxSize: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 11))
            tokenText(maxSize: maxSize)
        }
        .foregroundColor(.forTokenUsage(used: usedTokens, max: maxSize))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.surface.opacity(0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func tokenText(maxSize: Int) -> some View {
        if let used = usedTokens, used > 0 {
            Text("\(used.formattedTokensShort)/\(maxSize.formattedContextSize)")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        } else {
            Text(maxSize.formattedContextSize)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
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
            ?? providerManager.allLLMProviders().first?.providerInfo.id

        guard let providerID,
              let info = providerManager.providerInfo(id: providerID) else {
            maxContextSize = nil
            usedTokens = nil
            return
        }

        // A fresh install has no explicit global selection yet. The send path
        // uses the first provider and its default model in that case, so the
        // context-size indicator must resolve the same effective model.
        let modelName = conversationID.flatMap { conversationManager?.modelName(for: $0) }
            ?? providerManager.selectedModel
            ?? info.defaultModel
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
}
