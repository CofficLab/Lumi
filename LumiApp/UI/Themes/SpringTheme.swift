import SwiftUI

struct SpringTheme: ThemeProtocol {
    let identifier = "spring"
    let displayName = "春芽绿"
    let compactName = "春"
    let description = "春芽初醒，清新柔和"
    let iconName = "leaf.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "7CCF7A")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "7CCF7A"),
            secondary: SwiftUI.Color(hex: "F9A8D4"),
            tertiary: SwiftUI.Color(hex: "60A5FA")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "07110A"),
            medium: SwiftUI.Color(hex: "0D1A10"),
            light: SwiftUI.Color(hex: "13251A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "7CCF7A").opacity(0.3),
            medium: SwiftUI.Color(hex: "F9A8D4").opacity(0.5),
            intense: SwiftUI.Color(hex: "60A5FA").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 春日暖阳 (粉色微光)
                Circle()
                    .fill(accentColors().secondary.opacity(0.3))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: -150, y: -150)

                // 嫩芽生机 (绿色)
                Circle()
                    .fill(accentColors().primary.opacity(0.25))
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height)
                
                // 清泉点缀 (蓝色)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .position(x: proxy.size.width * 0.2, y: proxy.size.height * 0.7)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 300))
                        .foregroundStyle(accentColors().primary.opacity(0.05))
                        .rotationEffect(.degrees(30))
                        .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.1)
                        .blur(radius: 3)
                    
                    Image(systemName: "camera.macro")
                        .font(.system(size: 150))
                        .foregroundStyle(accentColors().secondary.opacity(0.08))
                        .rotationEffect(.degrees(-15))
                        .offset(x: -proxy.size.width * 0.2, y: proxy.size.height * 0.2)
                        .blur(radius: 5)
                }
            }
        )
    }
}
