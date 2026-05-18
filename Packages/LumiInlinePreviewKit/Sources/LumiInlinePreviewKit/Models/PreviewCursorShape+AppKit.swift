import AppKit

public extension LumiInlinePreviewFacade.PreviewCursorShape {
    init(appKit cursor: NSCursor) {
        switch cursor {
        case NSCursor.iBeam:
            self = .iBeam
        case NSCursor.pointingHand:
            self = .pointingHand
        case NSCursor.openHand:
            self = .openHand
        case NSCursor.closedHand:
            self = .closedHand
        case NSCursor.crosshair:
            self = .crosshair
        case NSCursor.resizeLeftRight:
            self = .resizeLeftRight
        case NSCursor.resizeUpDown:
            self = .resizeUpDown
        case NSCursor.operationNotAllowed:
            self = .operationNotAllowed
        case NSCursor.disappearingItem:
            self = .disappearingItem
        default:
            self = .arrow
        }
    }

    var appKitCursor: NSCursor {
        switch self {
        case .arrow:
            NSCursor.arrow
        case .iBeam:
            NSCursor.iBeam
        case .pointingHand:
            NSCursor.pointingHand
        case .openHand:
            NSCursor.openHand
        case .closedHand:
            NSCursor.closedHand
        case .crosshair:
            NSCursor.crosshair
        case .resizeLeftRight:
            NSCursor.resizeLeftRight
        case .resizeUpDown:
            NSCursor.resizeUpDown
        case .operationNotAllowed:
            NSCursor.operationNotAllowed
        case .disappearingItem:
            NSCursor.disappearingItem
        }
    }
}
