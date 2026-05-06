import Foundation
import LanguageServerProtocol

public struct EditorGutterDecorationContext: Equatable, Sendable {
    public let languageId: String
    public let currentLine: Int
    public let visibleLineRange: Range<Int>
    public let renderLineRange: Range<Int>
    public let isLargeFileMode: Bool

    public init(
        languageId: String,
        currentLine: Int,
        visibleLineRange: Range<Int>,
        renderLineRange: Range<Int>,
        isLargeFileMode: Bool
    ) {
        self.languageId = languageId
        self.currentLine = currentLine
        self.visibleLineRange = visibleLineRange
        self.renderLineRange = renderLineRange
        self.isLargeFileMode = isLargeFileMode
    }
}

public enum EditorGutterDecorationTone: Equatable, Sendable {
    case neutral
    case accent
    case info
    case success
    case warning
    case error
}

public enum EditorGitDecorationChangeKind: Equatable, Sendable {
    case added
    case modified
    case deleted
}

public enum EditorGutterDecorationKind: Equatable, Sendable {
    case diagnostic(EditorStatusLevel)
    case gitChange(EditorGitDecorationChangeKind)
    case symbol(SymbolKind)
    case custom(name: String, tone: EditorGutterDecorationTone, symbolName: String?)
}

public struct EditorGutterDecorationSuggestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let line: Int
    public let lane: Int
    public let kind: EditorGutterDecorationKind
    public let priority: Int
    public let badgeText: String?

    public init(
        id: String,
        line: Int,
        lane: Int = 0,
        kind: EditorGutterDecorationKind,
        priority: Int = 0,
        badgeText: String? = nil
    ) {
        self.id = id
        self.line = line
        self.lane = lane
        self.kind = kind
        self.priority = priority
        self.badgeText = badgeText
    }
}
