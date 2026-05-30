import LumiUI
import LumiCoreKit
import SwiftUI

public typealias AppMessageBubbleStyle = LumiUI.AppMessageBubbleStyle

extension MessageRole {
    public var lumiMessageBubbleRole: LumiUI.MessageBubbleRole {
        switch self {
        case .user:
            return .user
        case .assistant:
            return .assistant
        case .tool:
            return .tool
        case .status:
            return .status
        case .error:
            return .error
        case .system:
            return .system
        default:
            return .other
        }
    }
}

extension View {
    public func appMessageBubble(
        role: MessageRole,
        isError: Bool,
        style: AppMessageBubbleStyle = .default
    ) -> some View {
        self.appMessageBubble(
            role: role.lumiMessageBubbleRole,
            isError: isError,
            style: style
        )
    }
}
