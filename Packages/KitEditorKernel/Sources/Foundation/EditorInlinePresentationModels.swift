import Foundation

public enum EditorInlinePresentationKind: Equatable, Sendable {
    case message(EditorStatusLevel)
    case value
    case diff
}
