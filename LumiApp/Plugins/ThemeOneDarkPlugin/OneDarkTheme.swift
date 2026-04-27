import SwiftUI

// MARK: - One Dark 主题
///
/// 灵感来源于 Atom One Dark (One Dark Pro) 配色方案。
/// 特点：深邃的蓝灰色基调，色彩平衡且舒适
///
struct OneDarkTheme: ThemeProtocol {
    // MARK: - 主题信息
    let identifier = "one-dark"
    let displayName = "One Dark"
    let compactName = "One Dark"
    let description = "Atom One Dark 经典深色配色，舒适且平衡"
    let iconName = "circle.hexagongrid"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "528BFF")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "528BFF"),       // One Dark 标志性蓝色
            secondary: SwiftUI.Color(hex: "98C379"),      // One Dark 柔和绿色
            tertiary: SwiftUI.Color(hex: "C678DD")        // One Dark 紫罗兰色
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "282C34"),          // One Dark 核心背景色
            medium: SwiftUI.Color(hex: "21252B"),         // One Dark 侧边栏/面板背景
            light: SwiftUI.Color(hex: "353B45")           // One Dark 标签页/工具栏背景
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "528BFF").opacity(0.2),
            medium: SwiftUI.Color(hex: "528BFF").opacity(0.35),
            intense: SwiftUI.Color(hex: "C678DD").opacity(0.3)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                atmosphereColors().deep
                    .ignoresSafeArea()

                // 蓝色主光晕 (中心偏左)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.12),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 700, height: 700)
                    .blur(radius: 120)
                    .position(x: 200, y: proxy.size.height * 0.4)

                // 紫色光晕 (右下角)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().tertiary.opacity(0.08),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .position(x: proxy.size.width - 100, y: proxy.size.height - 100)

                // IDE 风格装饰
                ZStack {
                    Rectangle()
                        .fill(accentColors().primary.opacity(0.03))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: -250)

                    Rectangle()
                        .fill(accentColors().secondary.opacity(0.02))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: 250)

                    // 几何装饰
                    Image(systemName: "circle.hexagongrid")
                        .font(.system(size: 300))
                        .foregroundStyle(accentColors().primary.opacity(0.03))
                        .rotationEffect(.degrees(-15))
                        .position(x: proxy.size.width * 0.65, y: proxy.size.height * 0.65)
                        .blur(radius: 3)
                }
            }
        )
    }
}
