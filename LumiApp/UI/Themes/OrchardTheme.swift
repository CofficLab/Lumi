import SwiftUI

struct OrchardTheme: ThemeProtocol {
    let identifier = "orchard"
    let displayName = "果园红"
    let compactName = "果"
    let description = "果香微甜，鲜亮活力"
    let iconName = "apple.logo"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "F43F5E")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "F43F5E"),
            secondary: SwiftUI.Color(hex: "F97316"),
            tertiary: SwiftUI.Color(hex: "84CC16")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "14070B"),
            medium: SwiftUI.Color(hex: "1F0D12"),
            light: SwiftUI.Color(hex: "2B1118")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "F43F5E").opacity(0.3),
            medium: SwiftUI.Color(hex: "F97316").opacity(0.5),
            intense: SwiftUI.Color(hex: "84CC16").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 果实红 (左上)
                Circle()
                    .fill(accentColors().primary.opacity(0.25))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: -150, y: -150)

                // 橙色活力 (右中)
                Circle()
                    .fill(accentColors().secondary.opacity(0.3))
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height * 0.4)
                
                // 青柠绿 (左下)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.2))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .position(x: 0, y: proxy.size.height * 0.8)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 300))
                        .foregroundStyle(accentColors().primary.opacity(0.05))
                        .rotationEffect(.degrees(-10))
                        .offset(x: proxy.size.width * 0.25, y: -proxy.size.height * 0.1)
                        .blur(radius: 4)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 150))
                        .foregroundStyle(accentColors().tertiary.opacity(0.08))
                        .rotationEffect(.degrees(45))
                        .offset(x: -proxy.size.width * 0.2, y: proxy.size.height * 0.25)
                        .blur(radius: 3)
                }
            }
        )
    }
}
