import SwiftUI

struct RiverTheme: ThemeProtocol {
    let identifier = "river"
    let displayName = "河流青"
    let compactName = "河"
    let description = "清流涟漪，澄净通透"
    let iconName = "drop.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "0EA5E9")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "0EA5E9"),
            secondary: SwiftUI.Color(hex: "22D3EE"),
            tertiary: SwiftUI.Color(hex: "10B981")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "04111A"),
            medium: SwiftUI.Color(hex: "0A1E2B"),
            light: SwiftUI.Color(hex: "0F2A3A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "0EA5E9").opacity(0.3),
            medium: SwiftUI.Color(hex: "22D3EE").opacity(0.5),
            intense: SwiftUI.Color(hex: "10B981").opacity(0.7)
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
