import SwiftUI

public struct CommandSuggestionView: View {
    private let input: String
    private let onSelect: (String) -> Void

    public init(input: String = "", onSelect: @escaping (String) -> Void = { _ in }) {
        self.input = input
        self.onSelect = onSelect
    }

    public var body: some View {
        let suggestions = Self.suggestions(for: input)

        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion.command)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(suggestion.command)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 92, alignment: .leading)

                            Text(suggestion.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

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

    public static func suggestions(for input: String) -> [CommandSuggestion] {
        guard input.hasPrefix("/") else {
            return []
        }

        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allSuggestions.filter { suggestion in
            suggestion.command.lowercased().hasPrefix(normalized)
        }
    }

    private static let allSuggestions: [CommandSuggestion] = [
        CommandSuggestion(command: "/clear", description: String(localized: "Clear chat history", table: "ChatInputPlugin")),
        CommandSuggestion(command: "/help", description: String(localized: "Show all commands", table: "ChatInputPlugin")),
        CommandSuggestion(command: "/commands", description: String(localized: "List available commands", table: "ChatInputPlugin")),
        CommandSuggestion(command: "/cmd", description: String(localized: "List available commands", table: "ChatInputPlugin")),
        CommandSuggestion(command: "/plan", description: String(localized: "Plan a task", table: "ChatInputPlugin")),
        CommandSuggestion(command: "/mcp list", description: String(localized: "List MCP servers", table: "ChatInputPlugin")),
    ]
}

public struct CommandSuggestion: Identifiable, Equatable {
    public var id: String { command }
    public let command: String
    public let description: String

    public init(command: String, description: String) {
        self.command = command
        self.description = description
    }
}
