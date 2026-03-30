import SwiftUI

/// 通用拖拽覆盖提示层：用于整块区域拖拽接收时的引导反馈。
struct DropOverlayCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    init(
        icon: String = "folder.badge.plus",
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DesignTokens.Material.glass)
                .overlay(Color.black.opacity(0.12))
                .overlay(
                    Rectangle()
                        .stroke(
                            Color.accentColor.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                        )
                )

            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    DropOverlayCard(
        title: "松开即可添加项目",
        subtitle: "将文件夹拖到消息列表区域，自动切换为当前项目"
    )
    .frame(width: 640, height: 420)
    .inRootView()
}
