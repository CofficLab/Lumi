import Foundation

/// Plugin-local Codable model matching the `ask_user` wire shape.
///
/// Parsed from `LumiToolResult.content` of a suspended `ask_user` tool call.
/// Deliberately mirrors `AskUserPendingResponse` from `AskUserPlugin` without
/// importing it (the native list must not depend on the SwiftUI plugin).
public struct AppKitAskUserPayload: Codable, Equatable, Sendable {
    public let toolCallId: String
    public let question: String
    public let options: [AppKitAskUserOption]
    /// Interaction mode: `"yes_no"`, `"choice"`, `"free_text"`.
    /// Nil on legacy payloads; the renderer falls back to option inference.
    public let mode: String?
    public let conversationId: String
    public let verbosity: String

    public init(
        toolCallId: String,
        question: String,
        options: [AppKitAskUserOption],
        mode: String?,
        conversationId: String,
        verbosity: String
    ) {
        self.toolCallId = toolCallId
        self.question = question
        self.options = options
        self.mode = mode
        self.conversationId = conversationId
        self.verbosity = verbosity
    }

    /// Parses the payload from a suspended `ask_user` tool result content.
    public static func parse(from content: String?) -> AppKitAskUserPayload? {
        guard let content, let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AppKitAskUserPayload.self, from: data)
    }

    /// Effective interaction mode: explicit `mode`, falling back to inference
    /// from the options for legacy payloads.
    public var effectiveMode: Mode {
        switch mode?.lowercased() {
        case "yes_no", "yesno", "yes/no":
            return .yesNo
        case "choice":
            return .choice
        case "free_text", "freetext", "free-text":
            return .freeText
        default:
            if options.count == 2,
               options.allSatisfy({ ["是", "否", "yes", "no", "允许", "拒绝"].contains($0.label) }) {
                return .yesNo
            }
            if options.isEmpty { return .freeText }
            return .choice
        }
    }

    public enum Mode: Sendable, Equatable {
        case yesNo
        case choice
        case freeText
    }
}

/// A single selectable option, compatible with both wire shapes:
/// a bare string (label only) or `{"label": "...", "description": "..."}`.
public struct AppKitAskUserOption: Codable, Equatable, Sendable, Hashable {
    public let label: String
    public let description: String?

    public init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case label, description
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.label = try container.decode(String.self, forKey: .label)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
        } else {
            let container = try decoder.singleValueContainer()
            self.label = try container.decode(String.self)
            self.description = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let description {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encode(description, forKey: .description)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(label)
        }
    }
}
