import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import SwiftUI

/// 对话行
struct ConversationRow: View {
    let conversation: LumiConversationSummary
    let llmProvider: (any LLMProviderManaging)?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title.isEmpty ? "Untitled" : conversation.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(conversation.updatedAt.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Provider and model info
                if let providerID = conversation.providerID,
                   let providerInfo = providerInfo(for: providerID) {
                    HStack(spacing: 4) {
                        Text(providerInfo.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let modelName = conversation.modelName {
                            Text("·")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(displayModelName(providerID: providerID, model: modelName))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }

    private func providerInfo(for providerID: String) -> LumiLLMProviderInfo? {
        guard let provider = llmProvider?.allLLMProviders().first(where: {
            type(of: $0).info.id == providerID
        }) else {
            return nil
        }
        return type(of: provider).info
    }

    private func displayModelName(providerID: String, model: String) -> String {
        guard let info = providerInfo(for: providerID) else { return model }
        return info.modelDisplayNames[model] ?? model
    }
}
