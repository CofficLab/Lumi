import SwiftUI

struct SummerTheme: ThemeProtocol {
    let identifier = "summer"
    let displayName = "盛夏蓝"
    let compactName = "夏"
    let description = "炽阳海风，清澈明朗"
    let iconName = "sun.max.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "38BDF8")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "38BDF8"),
            secondary: SwiftUI.Color(hex: "FACC15"),
            tertiary: SwiftUI.Color(hex: "34D399")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "041018"),
            medium: SwiftUI.Color(hex: "082030"),
            light: SwiftUI.Color(hex: "0F2F3F")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "38BDF8").opacity(0.3),
            medium: SwiftUI.Color(hex: "FACC15").opacity(0.5),
            intense: SwiftUI.Color(hex: "34D399").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 盛夏烈阳 (黄色)
                Circle()
                    .fill(accentColors().secondary.opacity(0.4))
                    .frame(width: 700, height: 700)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: 0)

                // 清凉海风 (蓝色)
                Circle()
                    .fill(accentColors().primary.opacity(0.3))
                    .frame(width: 800, height: 800)
                    .blur(radius: 150)
                    .position(x: 0, y: proxy.size.height)
                
                // 树荫 (绿色)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.2))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.8)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 400))
                        .foregroundStyle(accentColors().secondary.opacity(0.05))
                        .rotationEffect(.degrees(10))
                        .offset(x: proxy.size.width * 0.25, y: -proxy.size.height * 0.25)
                        .blur(radius: 10)
                    
                    Image(systemName: "water.waves")
                        .font(.system(size: 200))
                        .foregroundStyle(accentColors().primary.opacity(0.06))
                        .offset(x: -proxy.size.width * 0.2, y: proxy.size.height * 0.35)
                        .blur(radius: 5)
                }
            }
        )
    }
}
