import SwiftUI

// MARK: - Dracula 主题
///
/// 严格遵循 Dracula Official 配色方案。
/// 特点：深邃的紫红色背景，高对比度的鲜艳色彩
///
struct DraculaTheme: SuperTheme {
    // MARK: - 主题信息
    let identifier = "dracula"
    let displayName = "Dracula"
    let compactName = "Dracula"
    let description = "Dracula Official 经典深色配色，高对比度且醒目"
    let iconName = "moon.stars.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "BD93F9")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "BD93F9"),       // Dracula 标志性紫罗兰
            secondary: SwiftUI.Color(hex: "FF79C6"),      // Dracula 亮粉色
            tertiary: SwiftUI.Color(hex: "8BE9FD")        // Dracula 亮青色
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "282A36"),          // Dracula 核心背景色
            medium: SwiftUI.Color(hex: "343746"),         // Dracula 侧边栏/面板背景
            light: SwiftUI.Color(hex: "44475A")           // Dracula 标签页/选中背景
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "BD93F9").opacity(0.2),
            medium: SwiftUI.Color(hex: "FF79C6").opacity(0.3),
            intense: SwiftUI.Color(hex: "FFB86C").opacity(0.35)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                atmosphereColors().deep
                    .ignoresSafeArea()

                // 紫罗兰主光晕 (中心偏右)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.15),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 700, height: 700)
                    .blur(radius: 130)
                    .position(x: proxy.size.width * 0.7, y: proxy.size.height * 0.3)

                // 粉色光晕 (左下角)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().secondary.opacity(0.1),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .blur(radius: 110)
                    .position(x: 100, y: proxy.size.height - 100)

                // IDE 风格装饰
                ZStack {
                    // 类似行号的装饰线
                    Rectangle()
                        .fill(accentColors().primary.opacity(0.03))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: -300)

                    // 月相/吸血鬼风格图标
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 250))
                        .foregroundStyle(accentColors().secondary.opacity(0.04))
                        .rotationEffect(.degrees(10))
                        .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.2)
                        .blur(radius: 3)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 150))
                        .foregroundStyle(accentColors().tertiary.opacity(0.035))
                        .rotationEffect(.degrees(-12))
                        .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.8)
                        .blur(radius: 2)
                }
            }
        )
    }
}
