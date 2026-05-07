import SwiftUI

// MARK: - GitHub 主题
///
/// 灵感来源于 GitHub 的深色主题设计。
/// 特点：GitHub 蓝绿调，代码风格的深邃质感
///
struct GitHubTheme: SuperTheme {
    // MARK: - 主题信息

    let identifier = "github"
    let displayName = "GitHub"
    let compactName = "GitHub"
    let description = "灵感来源于 GitHub 的深色主题，深邃而专业"
    let iconName = "chevron.left.forwardslash.chevron.right"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "24292E", dark: "58A6FF")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "1F6FEB", dark: "58A6FF"),    // GitHub 蓝
            secondary: SwiftUI.Color.adaptive(light: "238636", dark: "3FB950"),  // GitHub 绿
            tertiary: SwiftUI.Color.adaptive(light: "A371F7", dark: "BC8CFF")    // GitHub 紫（链接色）
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F6F8FA", dark: "0D1117"),      // 背景：GitHub 浅灰 vs GitHub Dark BG
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "161B22"),     // 卡片：GitHub box BG
            light: SwiftUI.Color.adaptive(light: "E1E4E8", dark: "21262D")       // 边框/高亮
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "238636", dark: "3FB950").opacity(0.2),
            medium: SwiftUI.Color.adaptive(light: "1F6FEB", dark: "58A6FF").opacity(0.35),
            intense: SwiftUI.Color.adaptive(light: "A371F7", dark: "BC8CFF").opacity(0.5)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                // 主背景
                atmosphereColors().deep
                    .ignoresSafeArea()
                
                // GitHub 绿光晕 (左上)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().secondary.opacity(0.12),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 700, height: 700)
                    .blur(radius: 120)
                    .position(x: 100, y: 100)

                // GitHub 蓝光晕 (右下)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.1),
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

                // 紫色点缀 (中间偏右)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.06))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .position(x: proxy.size.width * 0.7, y: proxy.size.height * 0.3)

                // 代码风格背景装饰
                ZStack {
                    // 类似代码行号的装饰线
                    Rectangle()
                        .fill(accentColors().primary.opacity(0.04))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: -250)

                    Rectangle()
                        .fill(accentColors().primary.opacity(0.03))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: 250)

                    // GitHub 标志性的 Octocat 风格圆形装饰
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 400))
                        .foregroundStyle(accentColors().primary.opacity(0.03))
                        .rotationEffect(.degrees(-15))
                        .position(x: proxy.size.width * 0.75, y: proxy.size.height * 0.75)
                        .blur(radius: 3)

                    Image(systemName: "terminal")
                        .font(.system(size: 200))
                        .foregroundStyle(accentColors().secondary.opacity(0.04))
                        .rotationEffect(.degrees(10))
                        .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.25)
                        .blur(radius: 2)
                }
            }
        )
    }
}
