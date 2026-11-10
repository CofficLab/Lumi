import CoreGraphics

enum ChatGPTConversationLayout {
    static let maximumContentWidth: CGFloat = 768

    static func horizontalPadding(for container: CGFloat) -> CGFloat {
        container >= 480 ? 24 : 16
    }

    static func contentWidth(for container: CGFloat) -> CGFloat {
        guard container.isFinite, container > 0 else { return 0 }
        let padding = horizontalPadding(for: container)
        return min(maximumContentWidth, max(0, container - 2 * padding))
    }

    static let turnSpacing: CGFloat = 32
    static let userAssistantSpacing: CGFloat = 16
    static let workItemSpacing: CGFloat = 12
    static let listTopSpacing: CGFloat = 16
    static let listBottomSpacing: CGFloat = 24
    static let bottomAnchorSpacing: CGFloat = 16

    static func userBubbleMaxWidth(contentWidth: CGFloat) -> CGFloat {
        guard contentWidth.isFinite, contentWidth > 0 else { return 0 }
        let fraction: CGFloat = contentWidth < 480 ? 0.92 : 0.8
        return min(contentWidth, min(560, contentWidth * fraction))
    }

    static let userBubbleCornerRadius: CGFloat = 18
    static let userBubbleHorizontalPadding: CGFloat = 16
    static let userBubbleVerticalPadding: CGFloat = 10
    static let bodyLineHeight: CGFloat = 24

    static let actionButtonSize: CGFloat = 28
    static let actionBarHeight: CGFloat = 32
    static let backToBottomButtonSize: CGFloat = 32
    static let backToBottomOffset: CGFloat = 16
    static let bottomTolerance: CGFloat = 48
}
