import SwiftUI

struct WinterTheme: ThemeProtocol {
    let identifier = "winter"
    let displayName = "霜冬白"
    let compactName = "冬"
    let description = "霜雪凝光，清冷静谧"
    let iconName = "snowflake"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "2563EB", dark: "60A5FA")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "2563EB", dark: "60A5FA"),  // 霜冬蓝 (浅色稍深)
            secondary: SwiftUI.Color.adaptive(light: "93C5FD", dark: "E0F2FE"), // 冰霜白
            tertiary: SwiftUI.Color.adaptive(light: "6366F1", dark: "A5B4FC")   // 极寒紫
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F8FAFC", dark: "060B16"),      // 背景：浅灰白 vs 深蓝黑
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "0D1424"),     // 卡片
            light: SwiftUI.Color.adaptive(light: "F1F5F9", dark: "16203A")       // 高光
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "2563EB", dark: "60A5FA").opacity(0.3),
            medium: SwiftUI.Color.adaptive(light: "93C5FD", dark: "E0F2FE").opacity(0.5),
            intense: SwiftUI.Color.adaptive(light: "6366F1", dark: "A5B4FC").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 冰霜白 (顶部覆盖)
                Ellipse()
                    .fill(accentColors().secondary.opacity(0.2))
                    .frame(width: proxy.size.width * 1.5, height: 600)
                    .blur(radius: 120)
                    .position(x: proxy.size.width / 2, y: 0)

                // 寒冬蓝 (左下)
                Circle()
                    .fill(accentColors().primary.opacity(0.25))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .position(x: 0, y: proxy.size.height)
                
                // 极寒紫 (右侧)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.2))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .position(x: proxy.size.width, y: proxy.size.height * 0.6)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "snowflake")
                        .font(.system(size: 350))
                        .foregroundStyle(accentColors().secondary.opacity(0.06))
                        .rotationEffect(.degrees(15))
                        .offset(x: proxy.size.width * 0.2, y: -proxy.size.height * 0.15)
                        .blur(radius: 4)
                    
                    Image(systemName: "thermometer.snowflake")
                        .font(.system(size: 150))
                        .foregroundStyle(accentColors().primary.opacity(0.08))
                        .rotationEffect(.degrees(-10))
                        .offset(x: -proxy.size.width * 0.25, y: proxy.size.height * 0.25)
                        .blur(radius: 3)
                }
            }
        )
    }
}
