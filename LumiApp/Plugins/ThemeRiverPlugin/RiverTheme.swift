import SwiftUI

struct RiverTheme: ThemeProtocol {
    let identifier = "river"
    let displayName = "河流青"
    let compactName = "河"
    let description = "清流涟漪，澄净通透"
    let iconName = "drop.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "0284C7", dark: "0EA5E9")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "0284C7", dark: "0EA5E9"),  // 河流蓝 (浅色更深)
            secondary: SwiftUI.Color.adaptive(light: "0891B2", dark: "22D3EE"), // 清澈青 (浅色更深)
            tertiary: SwiftUI.Color.adaptive(light: "059669", dark: "10B981")   // 岸边绿 (浅色更深)
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F0F9FF", dark: "04111A"),     // 浅色背景：淡水蓝
            medium: SwiftUI.Color.adaptive(light: "E0F2FE", dark: "0A1E2B"),
            light: SwiftUI.Color.adaptive(light: "BAE6FD", dark: "0F2A3A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "0284C7", dark: "0EA5E9").opacity(0.3),
            medium: SwiftUI.Color.adaptive(light: "0891B2", dark: "22D3EE").opacity(0.5),
            intense: SwiftUI.Color.adaptive(light: "059669", dark: "10B981").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 河流主干 (对角线流淌)
                Capsule()
                    .fill(accentColors().primary.opacity(0.25))
                    .frame(width: proxy.size.width * 1.2, height: 400)
                    .rotationEffect(.degrees(30))
                    .blur(radius: 100)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                // 清澈波光 (浅蓝)
                Circle()
                    .fill(accentColors().secondary.opacity(0.2))
                    .frame(width: 500, height: 500)
                    .blur(radius: 80)
                    .offset(x: -100, y: -100)
                
                // 岸边绿意 (底部)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.15))
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 300))
                        .foregroundStyle(accentColors().secondary.opacity(0.05))
                        .rotationEffect(.degrees(15))
                        .offset(x: proxy.size.width * 0.2, y: -proxy.size.height * 0.1)
                        .blur(radius: 5)
                    
                    Image(systemName: "water.waves.and.arrow.down")
                        .font(.system(size: 180))
                        .foregroundStyle(accentColors().primary.opacity(0.06))
                        .rotationEffect(.degrees(-10))
                        .offset(x: -proxy.size.width * 0.25, y: proxy.size.height * 0.3)
                        .blur(radius: 3)
                }
            }
        )
    }
}
