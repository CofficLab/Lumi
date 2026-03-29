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

#Preview {
    HStack(spacing: 10) {
        AppAvatar(systemImage: "cpu", tint: .blue, backgroundTint: .blue.opacity(0.12))
        AppAvatar(systemImage: "person.fill", tint: .green, backgroundTint: .green.opacity(0.12))
    }
    .padding()
    .inRootView()
}
