import SwiftUI

struct AutumnTheme: ThemeProtocol {
    let identifier = "autumn"
    let displayName = "秋枫橙"
    let compactName = "秋"
    let description = "枫影微红，温润深远"
    let iconName = "wind"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "F97316")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "F97316"),
            secondary: SwiftUI.Color(hex: "DC2626"),
            tertiary: SwiftUI.Color(hex: "A16207")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "160B05"),
            medium: SwiftUI.Color(hex: "2A1408"),
            light: SwiftUI.Color(hex: "3A1F0F")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "F97316").opacity(0.3),
            medium: SwiftUI.Color(hex: "DC2626").opacity(0.5),
            intense: SwiftUI.Color(hex: "A16207").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 枫叶红 (中心偏左)
                Circle()
                    .fill(accentColors().secondary.opacity(0.25))
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .position(x: proxy.size.width * 0.3, y: proxy.size.height * 0.4)

                // 金秋黄 (右下)
                Circle()
                    .fill(accentColors().primary.opacity(0.3))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .position(x: proxy.size.width, y: proxy.size.height)
                
                // 大地棕 (底部)
                Ellipse()
                    .fill(accentColors().tertiary.opacity(0.2))
                    .frame(width: proxy.size.width * 1.2, height: 400)
                    .blur(radius: 120)
                    .position(x: proxy.size.width / 2, y: proxy.size.height)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "wind")
                        .font(.system(size: 350))
                        .foregroundStyle(accentColors().secondary.opacity(0.05))
                        .offset(x: -proxy.size.width * 0.15, y: -proxy.size.height * 0.1)
                        .blur(radius: 8)
                    
                    Image(systemName: "leaf.arrow.circlepath")
                        .font(.system(size: 180))
                        .foregroundStyle(accentColors().primary.opacity(0.08))
                        .rotationEffect(.degrees(25))
                        .offset(x: proxy.size.width * 0.3, y: proxy.size.height * 0.2)
                        .blur(radius: 3)
                }
            }
        )
    }
}
