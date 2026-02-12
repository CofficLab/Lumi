//
//  AuroraTheme.swift
//  Lumi
//
//  Created by Design System on 2025-02-11.
//  极光紫主题
//

import SwiftUI

// MARK: - 极光紫主题
///
/// 绚丽的极光紫，梦幻而优雅。
/// 特点：紫色调，天空与自然的和谐
///
struct AuroraTheme: ThemeProtocol {
    // MARK: - 主题信息

    let identifier = "aurora"
    let displayName = "极光紫"
    let compactName = "极光"
    let description = "绚丽的极光紫，梦幻而优雅"
    let iconName = "sparkles"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "A78BFA")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "A78BFA"),  // 极光紫
            secondary: SwiftUI.Color(hex: "38BDF8"), // 天空蓝
            tertiary: SwiftUI.Color(hex: "34D399")  // 极光绿
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "0A0515"),     // 极光深邃
            medium: SwiftUI.Color(hex: "120A20"),   // 极光中层
            light: SwiftUI.Color(hex: "1F1535")     // 极光浅层
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "A78BFA").opacity(0.3),
            medium: SwiftUI.Color(hex: "38BDF8").opacity(0.5),
            intense: SwiftUI.Color(hex: "34D399").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                // 极光深色背景
                backgroundGradient()
                    .ignoresSafeArea()

                // 极光带 1 (绿色)
                Capsule()
                    .fill(accentColors().tertiary.opacity(0.25))
                    .frame(width: 800, height: 300)
                    .rotationEffect(.degrees(-30))
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)

                // 极光带 2 (紫色)
                Capsule()
                    .fill(accentColors().primary.opacity(0.3))
                    .frame(width: 900, height: 400)
                    .rotationEffect(.degrees(-15))
                    .blur(radius: 100)
                    .offset(x: 200, y: 100)
                
                // 极光带 3 (蓝色)
                Capsule()
                    .fill(accentColors().secondary.opacity(0.2))
                    .frame(width: 700, height: 250)
                    .rotationEffect(.degrees(-45))
                    .blur(radius: 90)
                    .position(x: proxy.size.width, y: proxy.size.height - 100)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 400))
                        .foregroundStyle(accentColors().tertiary.opacity(0.05))
                        .rotationEffect(.degrees(20))
                        .offset(x: proxy.size.width * 0.2, y: proxy.size.height * 0.1)
                        .blur(radius: 10)
                    
                    Image(systemName: "rays")
                        .font(.system(size: 250))
                        .foregroundStyle(accentColors().primary.opacity(0.03))
                        .offset(x: -proxy.size.width * 0.25, y: -proxy.size.height * 0.25)
                        .blur(radius: 5)
                }
            }
        )
    }
}
