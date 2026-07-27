import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的模型选择按钮
struct ActionBarButton: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    @State private var isPopoverPresented = false

    /// 从 kernel 获取服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    private var conversationManaging: (any ConversationManaging)? {
        kernel.resolveService((any ConversationManaging).self)
    }

    /// Initial selection: conversation provider/model if exists, else from LLMProviderManaging
    private var initialSelection: (providerID: String?, model: String?) {
        // Check conversation first
        if let conversations = conversationManaging,
           let convID = conversations.selectedConversationID,
           let convProviderID = conversations.providerID(for: convID) {
            let convModel = conversations.modelName(for: convID)
            return (convProviderID, convModel)
        }
        // Fallback to LLMProviderManaging
        return (llmProvider?.selectedProviderID, llmProvider?.selectedModel)
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                Text(buttonLabel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.textTertiary.opacity(0.2))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            PopoverContent(
                kernel: kernel,
                isPresented: $isPopoverPresented
            )
        }
        .accessibilityLabel("Select Model")
    }

    private var buttonLabel: String {
        guard let llmProvider else { return "Select Provider" }
        let selection = initialSelection
        guard let providerID = selection.providerID,
              let provider = llmProvider.allLLMProviders().first(where: { type(of: $0).info.id == providerID })
        else {
            return "Select Provider"
        }
        let info = type(of: provider).info
        if let model = selection.model {
            let displayModel = info.modelDisplayNames[model] ?? model
            return "\(info.displayName) · \(displayModel)"
        }
        return info.displayName
    }
}
