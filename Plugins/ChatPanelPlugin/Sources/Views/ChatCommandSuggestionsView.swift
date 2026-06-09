import LumiUI
import SwiftUI

struct ChatSlashCommand: Identifiable, Equatable {
    var id: String { command }
    let command: String
    let description: String
    var isSelected: Bool = false

    static func suggestions(for input: String) -> [ChatSlashCommand] {
        guard input.hasPrefix("/") else { return [] }
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.filter { $0.command.lowercased().hasPrefix(normalized) }
    }

    private static let all: [ChatSlashCommand] = [
        .init(command: "/clear", description: "Clear chat history"),
        .init(command: "/help", description: "Show available commands"),
        .init(command: "/model", description: "Open model selector"),
    ]
}

struct ChatCommandSuggestionsView: View {
    let suggestions: [ChatSlashCommand]
    let isVisible: Bool
    let onSelect: (ChatSlashCommand) -> Void

    var body: some View {
        if isVisible, !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Text(suggestion.command)
                                .font(.caption.weight(.semibold))
                                .frame(width: 92, alignment: .leading)
                            Text(suggestion.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
