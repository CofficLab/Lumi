import CoreGraphics

public enum LumiChatSectionLayout: Sendable, Equatable {
    case none
    case narrow
    case wide

    public var isVisible: Bool {
        self != .none
    }

    public var minWidth: CGFloat {
        switch self {
        case .none: 0
        case .narrow: 280
        case .wide: 400
        }
    }

    public var idealWidth: CGFloat {
        switch self {
        case .none: 0
        case .narrow: 320
        case .wide: 480
        }
    }

    public var defaultWidth: CGFloat {
        idealWidth
    }

    public var maximumWidth: CGFloat {
        switch self {
        case .none: 0
        case .narrow: 420
        case .wide: 960
        }
    }

    /// 为 ChatSection 预留宽度后，其余区域至少保留的宽度（ActivityBar + 主内容区）。
    public var minimumRemainingWidth: CGFloat {
        switch self {
        case .none: 0
        case .narrow: 560
        case .wide: 360
        }
    }

    public var persistenceKeySuffix: String {
        switch self {
        case .none: "none"
        case .narrow: "narrow"
        case .wide: "wide"
        }
    }
}
