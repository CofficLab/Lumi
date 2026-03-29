import SwiftUI

/// 通用头像组件：统一消息角色头像视觉。
struct AppAvatar: View {
    let systemImage: String
    let tint: Color
    let backgroundTint: Color
    let size: CGFloat

    init(
        systemImage: String,
        tint: Color,
        backgroundTint: Color,
        size: CGFloat = 24
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.backgroundTint = backgroundTint
        self.size = size
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: max(10, size * 0.66)))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(backgroundTint)
            .clipShape(Circle())
    }
}

/// 通用图片缩略图组件：调用方只需传形状，不需要关心 DesignTokens。
struct AppImageThumbnail: View {
    enum ShapeStyle {
        case roundedSmall
        case roundedMedium
        case rounded(CGFloat)
        case circle
        case capsule
    }

    let image: Image
    let size: CGSize
    let contentMode: ContentMode
    let shape: ShapeStyle

    init(
        image: Image,
        size: CGSize,
        contentMode: ContentMode = .fill,
        shape: ShapeStyle = .roundedMedium
    ) {
        self.image = image
        self.size = size
        self.contentMode = contentMode
        self.shape = shape
    }

    var body: some View {
        switch shape {
        case .roundedSmall:
            baseImage
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        case .roundedMedium:
            baseImage
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        case let .rounded(radius):
            baseImage
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .circle:
            baseImage
                .clipShape(Circle())
        case .capsule:
            baseImage
                .clipShape(Capsule())
        }
    }

    private var baseImage: some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
    }
}

#Preview {
    HStack(spacing: 10) {
        AppAvatar(systemImage: "cpu", tint: .blue, backgroundTint: .blue.opacity(0.12))
        AppAvatar(systemImage: "person.fill", tint: .green, backgroundTint: .green.opacity(0.12))
    }
    .padding()
    .inRootView()
}
