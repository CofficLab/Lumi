import LumiCoreMessage
import SwiftUI

/// 对话行
struct ConversationRow: View {
    let conversation: LumiConversationSummary
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
                Text(conversation.id.uuidString)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
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
}
