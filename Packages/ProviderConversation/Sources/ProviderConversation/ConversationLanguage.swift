import Foundation

/// 回复语言。
public enum ConversationLanguage: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chinese
    case english

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .chinese: "zh"
        case .english: "en"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "zh", "chinese", "cn": self = .chinese
        case "en", "english": self = .english
        default: return nil
        }
    }

    public var shortCode: String {
        switch self { case .chinese: "中"; case .english: "EN" }
    }

    public var displayName: String {
        switch self { case .chinese: "中文"; case .english: "English" }
    }

    public var iconName: String {
        "character.book.closed"
    }
}
