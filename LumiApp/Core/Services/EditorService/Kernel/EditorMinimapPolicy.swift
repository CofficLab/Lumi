import Foundation

struct EditorMinimapPolicy: Equatable {
    let userRequestedVisible: Bool
    let largeFileMode: LargeFileMode

    var isForcedHidden: Bool {
        largeFileMode.isMinimapDisabled
    }

    var isVisible: Bool {
        userRequestedVisible && !isForcedHidden
    }

    var statusTitle: String {
        if isVisible {
            return "Minimap On"
        }
        if isForcedHidden {
            return "Minimap Gated"
        }
        return "Minimap Off"
    }

    var detailText: String {
        if isForcedHidden {
            switch largeFileMode {
            case .large:
                return "Minimap hidden in large file mode to keep viewport rendering responsive."
            case .mega:
                return "Minimap hidden in mega file mode to reduce memory and layout cost."
            case .normal, .medium:
                break
            }
        }
        return userRequestedVisible
            ? "Minimap is visible for the current editor."
            : "Minimap is turned off in editor settings."
    }
}
