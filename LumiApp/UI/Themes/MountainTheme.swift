import SwiftUI

struct MountainTheme: ThemeProtocol {
    let identifier = "mountain"
    let displayName = "山岚灰"
    let compactName = "山"
    let description = "石色沉稳，松影清远"
    let iconName = "mountain.2.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "475569", dark: "64748B")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "475569", dark: "64748B"),  // 山岚灰 (浅色更深)
            secondary: SwiftUI.Color.adaptive(light: "64748B", dark: "94A3B8"), // 雾凇白 (浅色转深灰)
            tertiary: SwiftUI.Color.adaptive(light: "16A34A", dark: "22C55E")   // 松针绿 (浅色更深)
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F1F5F9", dark: "0A0C10"),     // 浅色背景：云雾白
            medium: SwiftUI.Color.adaptive(light: "E2E8F0", dark: "12161D"),
            light: SwiftUI.Color.adaptive(light: "CBD5E1", dark: "1C2230")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "475569", dark: "64748B").opacity(0.3),
            medium: SwiftUI.Color.adaptive(light: "64748B", dark: "94A3B8").opacity(0.5),
            intense: SwiftUI.Color.adaptive(light: "16A34A", dark: "22C55E").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 远山灰 (底部大面积)
                Ellipse()
                    .fill(accentColors().primary.opacity(0.3))
                    .frame(width: proxy.size.width * 1.5, height: 800)
                    .blur(radius: 150)
                    .position(x: proxy.size.width / 2, y: proxy.size.height + 200)

                // 云雾白 (顶部)
                Ellipse()
                    .fill(accentColors().secondary.opacity(0.15))
                    .frame(width: proxy.size.width * 1.2, height: 500)
                    .blur(radius: 120)
                    .position(x: proxy.size.width / 2, y: -100)
                
                // 松林绿 (右下角点缀)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.2))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .position(x: proxy.size.width, y: proxy.size.height)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 400))
                        .foregroundStyle(accentColors().primary.opacity(0.05))
                        .offset(x: 0, y: proxy.size.width * 0.1) // 稍微下沉
                        .blur(radius: 6)
                    
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 200))
                        .foregroundStyle(accentColors().secondary.opacity(0.08))
                        .offset(x: -proxy.size.width * 0.3, y: -proxy.size.height * 0.25)
                        .blur(radius: 8)
                }
            }
        )
    }
}
