import LumiCoreKit
import SwiftUI

public struct CommandSuggestionView: View {
    private let suggestions: [ChatCommandSuggestion]
    private let isVisible: Bool
    private let version: Int
    private let onSelect: (ChatCommandSuggestion) -> Void

    public init(
        suggestions: [ChatCommandSuggestion] = [],
        isVisible: Bool = false,
        version: Int = 0,
        onSelect: @escaping (ChatCommandSuggestion) -> Void = { _ in }
    ) {
        self.suggestions = suggestions
        self.isVisible = isVisible
        self.version = version
        self.onSelect = onSelect
    }

    public var body: some View {
        if isVisible, !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
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
                        .background(suggestion.isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .id(version)
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
        CommandSuggestion(command: "/clear", description: String(localized: "Clear chat history", bundle: .module)),
        CommandSuggestion(command: "/help", description: String(localized: "Show all commands", bundle: .module)),
        CommandSuggestion(command: "/commands", description: String(localized: "List available commands", bundle: .module)),
        CommandSuggestion(command: "/cmd", description: String(localized: "List available commands", bundle: .module)),
        CommandSuggestion(command: "/plan", description: String(localized: "Plan a task", bundle: .module)),
        CommandSuggestion(command: "/mcp list", description: String(localized: "List MCP servers", bundle: .module)),
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
