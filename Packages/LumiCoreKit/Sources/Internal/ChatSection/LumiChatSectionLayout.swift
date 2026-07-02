import CoreGraphics

public enum LumiChatSectionLayout: Sendable, Equatable {
    case none
    case narrow
    case wide

    private static let resizableMinWidth: CGFloat = 280
    private static let resizableMaxWidth: CGFloat = .infinity
    private static let minimumMainContentWidth: CGFloat = 360

    public var isVisible: Bool {
        self != .none
    }

    public var minWidth: CGFloat {
        switch self {
        case .none: 0
        case .narrow, .wide: Self.resizableMinWidth
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
        case .narrow, .wide: Self.resizableMaxWidth
        }
    }

    /// 为 ChatSection 预留宽度后，其余区域至少保留的宽度（ActivityBar + 主内容区）。
    public var minimumRemainingWidth: CGFloat {
        switch self {
        case .none: 0
        case .narrow, .wide: Self.minimumMainContentWidth
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
