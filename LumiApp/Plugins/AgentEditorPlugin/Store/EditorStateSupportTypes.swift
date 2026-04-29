import Foundation
import CoreGraphics

struct BracketOverlayRects: Equatable {
    let open: CGRect
    let close: CGRect
}

struct FindMatchOverlayHighlight: Equatable {
    let range: EditorRange
    let rect: CGRect
    let isSelected: Bool
}

enum EditorStatusLevel {
    case info
    case success
    case warning
    case error
}

struct BracketMatchResult: Equatable {
    let openOffset: Int
    let closeOffset: Int

    var ranges: [NSRange] {
        [
            NSRange(location: openOffset, length: 1),
            NSRange(location: closeOffset, length: 1),
        ]
    }
}

enum LineEditKind {
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

enum CursorMotionKind {
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
