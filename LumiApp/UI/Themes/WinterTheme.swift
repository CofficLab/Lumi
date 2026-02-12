import SwiftUI

struct WinterTheme: ThemeProtocol {
    let identifier = "winter"
    let displayName = "霜冬白"
    let compactName = "冬"
    let description = "霜雪凝光，清冷静谧"
    let iconName = "snowflake"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "60A5FA")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "60A5FA"),
            secondary: SwiftUI.Color(hex: "E0F2FE"),
            tertiary: SwiftUI.Color(hex: "A5B4FC")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "060B16"),
            medium: SwiftUI.Color(hex: "0D1424"),
            light: SwiftUI.Color(hex: "16203A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "60A5FA").opacity(0.3),
            medium: SwiftUI.Color(hex: "E0F2FE").opacity(0.5),
            intense: SwiftUI.Color(hex: "A5B4FC").opacity(0.7)
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
