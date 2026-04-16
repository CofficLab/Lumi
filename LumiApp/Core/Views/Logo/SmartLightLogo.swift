import SwiftUI

/// 智能光源 Logo
/// 概念：圆形 + 闪电，象征"点亮灵感、照亮问题"
struct SmartLightLogo: View {
    /// 当前使用场景
    var scene: LogoScene = .general

    // MARK: - State

    @State private var isBreathing = false

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            contentView(size: size)
                .frame(width: size, height: size)
                .onAppear {
                    if !isAnimationDisabled {
                        withAnimation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            isBreathing = true
                        }
                    }
                }
        }
    }

    // MARK: - 主视图

    @ViewBuilder
    private func contentView(size: CGFloat) -> some View {
        switch scene {
        case .general:
            generalLogo(size: size)
        case .appIcon:
            appIconLogo(size: size)
        case .about:
            aboutLogo(size: size)
        case .statusBarInactive:
            statusBarInactiveLogo(size: size)
        case .statusBarActive:
            statusBarActiveLogo(size: size)
        }
    }

    // MARK: - 各场景子视图

    /// 通用场景 — 带呼吸动画的彩色渐变圆形
    @ViewBuilder
    private func generalLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.8

        // 呼吸光晕
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.5),
                        Color.clear,
                    ]),
                    center: .center,
                    startRadius: mainSize * 0.3,
                    endRadius: size * 0.5
                )
            )
            .scaleEffect(isBreathing ? 1.15 : 1.0)
            .opacity(isBreathing ? 1.0 : 0.6)

        // 实心圆形背景
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .yellow.opacity(0.85)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: mainSize, height: mainSize)
            .shadow(color: .orange.opacity(0.3), radius: isBreathing ? 8 : 4)

        // 闪电图标
        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.white)
            .frame(width: mainSize * 0.35, height: mainSize * 0.35)
            .shadow(color: .white.opacity(0.6), radius: 2)
    }

    /// App 图标 — 同通用场景，额外添加阴影和黑色背景
    @ViewBuilder
    private func appIconLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.8

        // 呼吸光晕
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.5),
                        Color.clear,
                    ]),
                    center: .center,
                    startRadius: mainSize * 0.3,
                    endRadius: size * 0.5
                )
            )
            .scaleEffect(isBreathing ? 1.15 : 1.0)
            .opacity(isBreathing ? 1.0 : 0.6)

        // 实心圆形背景
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .yellow.opacity(0.85)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: mainSize, height: mainSize)
            .shadow(color: .orange.opacity(0.3), radius: isBreathing ? 8 : 4)

        // 闪电图标
        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.white)
            .frame(width: mainSize * 0.35, height: mainSize * 0.35)
            .shadow(color: .white.opacity(0.6), radius: 2)
    }

    /// 关于窗口 — 同通用场景，额外添加柔和阴影
    @ViewBuilder
    private func aboutLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.8

        // 呼吸光晕
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.5),
                        Color.clear,
                    ]),
                    center: .center,
                    startRadius: mainSize * 0.3,
                    endRadius: size * 0.5
                )
            )
            .scaleEffect(isBreathing ? 1.15 : 1.0)
            .opacity(isBreathing ? 1.0 : 0.6)

        // 实心圆形背景
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .yellow.opacity(0.85)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: mainSize, height: mainSize)
            .shadow(color: .orange.opacity(0.3), radius: isBreathing ? 8 : 4)

        // 闪电图标
        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.white)
            .frame(width: mainSize * 0.35, height: mainSize * 0.35)
            .shadow(color: .white.opacity(0.6), radius: 2)
    }

    /// 菜单栏（未激活） — 单色，无动画
    @ViewBuilder
    private func statusBarInactiveLogo(size: CGFloat) -> some View {
        // 实心圆形背景
        Circle()
            .fill(.primary)
            .frame(width: size * 0.8, height: size * 0.8)

        // 闪电图标
        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.white)
            .frame(width: size * 0.5, height: size * 0.5)
            .shadow(color: .white.opacity(0.6), radius: 2)
    }

    /// 菜单栏（已激活） — 彩色，无动画
    @ViewBuilder
    private func statusBarActiveLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.8

        // 呼吸光晕（减弱）
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.3),
                        Color.clear,
                    ]),
                    center: .center,
                    startRadius: mainSize * 0.3,
                    endRadius: size * 0.5
                )
            )

        // 实心圆形背景
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .yellow.opacity(0.85)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: mainSize, height: mainSize)
            .shadow(color: .orange.opacity(0.3), radius: 4)

        // 闪电图标
        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.white)
            .frame(width: size * 0.5, height: size * 0.5)
            .shadow(color: .white.opacity(0.6), radius: 2)
    }

    // MARK: - 辅助属性

    private var isAnimationDisabled: Bool {
        scene == .statusBarInactive || scene == .statusBarActive
    }
}

// MARK: - 预览

#Preview("General") {
    SmartLightLogo(scene: .general)
        .frame(width: 120, height: 120)
        .padding()
}

#Preview("App Icon") {
    SmartLightLogo(scene: .appIcon)
        .frame(width: 120, height: 120)
        .padding()
}

#Preview("About") {
    SmartLightLogo(scene: .about)
        .frame(width: 120, height: 120)
        .padding()
}

#Preview("Status Bar - Inactive") {
    HStack(spacing: 20) {
        SmartLightLogo(scene: .statusBarInactive)
            .frame(width: 22, height: 22)
            .background(Color.black)

        SmartLightLogo(scene: .statusBarInactive)
            .frame(width: 22, height: 22)
            .background(Color.white)
    }
    .padding()
}

#Preview("Status Bar - Active") {
    SmartLightLogo(scene: .statusBarActive)
        .frame(width: 22, height: 22)
        .background(Color.black)
        .padding()
}
