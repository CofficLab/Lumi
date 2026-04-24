import SwiftUI

// MARK: - 虚空深黑主题
///
/// 纯粹的虚空黑，深邃而神秘。
/// 特点：黑靛色调，极简主义
///
struct VoidTheme: ThemeProtocol {
    // MARK: - 主题信息

    let identifier = "void"
    let displayName = "虚空深黑"
    let compactName = "虚空"
    let description = "纯粹的虚空黑，深邃而神秘"
    let iconName = "circle.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "4F46E5", dark: "6366F1")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "4F46E5", dark: "6366F1"),  // 虚空靛 (浅色稍深)
            secondary: SwiftUI.Color.adaptive(light: "7C3AED", dark: "8B5CF6"), // 虚空紫
            tertiary: SwiftUI.Color.adaptive(light: "DB2777", dark: "EC4899")   // 虚空粉
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "F9FAFB", dark: "020205"),      // 背景：浅灰 vs 深黑
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "080810"),     // 卡片
            light: SwiftUI.Color.adaptive(light: "E5E7EB", dark: "101018")       // 高光
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "4F46E5", dark: "6366F1").opacity(0.3),
            medium: SwiftUI.Color.adaptive(light: "7C3AED", dark: "8B5CF6").opacity(0.5),
            intense: SwiftUI.Color.adaptive(light: "DB2777", dark: "EC4899").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                // 极简深黑背景
                atmosphereColors().deep
                    .ignoresSafeArea()
                
                // 虚空微光 (中心极微弱)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.15),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                // 边缘微光
                Circle()
                    .fill(accentColors().secondary.opacity(0.05))
                    .frame(width: 800, height: 800)
                    .blur(radius: 150)
                    .offset(x: 400, y: 400)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 500))
                        .foregroundStyle(accentColors().primary.opacity(0.02))
                        .rotationEffect(.degrees(45))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .blur(radius: 2)
                }
            }
        )
    }
}
