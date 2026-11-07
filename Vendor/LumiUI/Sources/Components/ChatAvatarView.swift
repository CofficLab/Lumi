import SwiftUI

public enum ChatAvatarKind {
    case assistant
    case user
    case tool
    case status
    case error
    case system
}

public struct ChatAvatarView: View {
    let kind: ChatAvatarKind

    public init(kind: ChatAvatarKind) {
        self.kind = kind
    }

    public var body: some View {
        switch kind {
        case .assistant:
            AvatarView.assistant
        case .user:
            AvatarView.user
        case .tool:
            AvatarView.tool
        case .status:
            AvatarView.status
        case .error:
            AvatarView.error
        case .system:
            AvatarView.system
        }
    }
}

@MainActor
public enum AvatarView {
    /// 预构建的静态实例:`Color(hex:)` 是字符串解析,历史上每次 body 求值
    /// (每个消息行 header、每次滚动重物化)都重新解析;视图值为值语义,
    /// 静态存储可安全复用。adaptive 颜色在渲染期自适应外观,缓存值不丢失该行为。
    public static let assistant: some View = AppAvatar(
        systemImage: "cpu",
        tint: Color(hex: "7C6FFF"),
        backgroundTint: Color(hex: "7C6FFF").opacity(0.1)
    )

    public static let user: some View = AppAvatar(
        systemImage: "person.fill",
        tint: Color(hex: "0A84FF"),
        backgroundTint: Color(hex: "0A84FF").opacity(0.1)
    )

    public static let tool: some View = AppAvatar(
        systemImage: "gearshape.2.fill",
        tint: Color(hex: "98989E"),
        backgroundTint: Color(hex: "98989E").opacity(0.1)
    )

    public static let status: some View = AppAvatar(
        systemImage: "sparkles",
        tint: Color(hex: "FF9F0A"),
        backgroundTint: Color(hex: "FF9F0A").opacity(0.12)
    )

    public static let error: some View = AppAvatar(
        systemImage: "exclamationmark.triangle.fill",
        tint: Color(hex: "FF453A"),
        backgroundTint: Color(hex: "FF453A").opacity(0.12)
    )

    public static let system: some View = AppAvatar(
        systemImage: "bolt.shield.fill",
        tint: Color.adaptive(light: "6B6B7B", dark: "EBEBF5"),
        backgroundTint: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.10)
    )
}

#Preview {
    HStack(spacing: 16) {
        ChatAvatarView(kind: .assistant)
        ChatAvatarView(kind: .user)
        ChatAvatarView(kind: .tool)
        ChatAvatarView(kind: .status)
        ChatAvatarView(kind: .error)
        ChatAvatarView(kind: .system)
    }
    .padding()
    .frame(width: 300)
    .background(Color.gray.opacity(0.15))
}
