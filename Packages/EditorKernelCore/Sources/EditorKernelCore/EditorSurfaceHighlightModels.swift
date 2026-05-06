import Foundation

public enum EditorSurfaceHighlightKind: Equatable, Sendable {
    case currentLine
    case findMatch
    case currentMatch
    case bracketMatch
    case hoverSymbol
}
