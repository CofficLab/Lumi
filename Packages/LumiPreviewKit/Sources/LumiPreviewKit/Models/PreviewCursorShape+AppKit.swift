import AppKit

public extension LumiPreviewFacade.PreviewCursorShape {
    init(appKit cursor: NSCursor) {
        if cursor === NSCursor.arrow {
            self = .arrow
        } else if cursor === NSCursor.iBeam {
            self = .iBeam
        } else if cursor === NSCursor.pointingHand {
            self = .pointingHand
        } else if cursor === NSCursor.openHand {
            self = .openHand
        } else if cursor === NSCursor.closedHand {
            self = .closedHand
        } else if cursor === NSCursor.crosshair {
            self = .crosshair
        } else if cursor === NSCursor.resizeLeftRight {
            self = .resizeLeftRight
        } else if cursor === NSCursor.resizeUpDown {
            self = .resizeUpDown
        } else if cursor === NSCursor.operationNotAllowed {
            self = .operationNotAllowed
        } else if cursor === NSCursor.disappearingItem {
            self = .disappearingItem
        } else {
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
