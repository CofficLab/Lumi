import Foundation

public enum EditorStatusLevel: Equatable, Sendable {
    case info
    case success
    case warning
    case error
}

public struct BracketMatchResult: Equatable, Sendable {
    public let openOffset: Int
    public let closeOffset: Int

    public var ranges: [NSRange] {
        [
            NSRange(location: openOffset, length: 1),
            NSRange(location: closeOffset, length: 1),
        ]
    }

    public init(openOffset: Int, closeOffset: Int) {
        self.openOffset = openOffset
        self.closeOffset = closeOffset
    }
}

public enum LineEditKind: Equatable, Sendable {
    case deleteLine
    case copyLineUp
    case copyLineDown
    case moveLineUp
    case moveLineDown
    case insertLineBelow
    case insertLineAbove
    case sortLinesAscending
    case sortLinesDescending
    case toggleLineComment
    case transpose
}

public enum CursorMotionKind: Equatable, Sendable {
    case wordLeft
    case wordRight
    case wordLeftSelect
    case wordRightSelect
    case smartHome
    case smartHomeSelect
    case lineEnd
    case lineEndSelect
    case documentStart
    case documentEnd
    case deleteWordLeft
    case deleteWordRight
    case paragraphBackward
    case paragraphForward
}
