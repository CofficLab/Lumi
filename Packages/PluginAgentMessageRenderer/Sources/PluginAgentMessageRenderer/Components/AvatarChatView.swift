import LumiUI
import LumiCoreKit
import SwiftUI

public struct AvatarChatView: View {
    public let role: MessageRole
    public let isToolOutput: Bool

    public init(role: MessageRole, isToolOutput: Bool) {
        self.role = role
        self.isToolOutput = isToolOutput
    }

    public var body: some View {
        ChatAvatarView(kind: avatarKind)
    }

    private var avatarKind: ChatAvatarKind {
        if isToolOutput || role == .tool {
            return .tool
        }

        switch role {
        case .user:
            return .user
        case .status:
            return .status
        case .error:
            return .error
        case .system:
            return .system
        default:
            return .assistant
        }
    }
}

typealias AvatarView = LumiUI.AvatarView
