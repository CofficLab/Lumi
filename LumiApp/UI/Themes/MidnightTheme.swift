//
//  MidnightTheme.swift
//  Lumi
//
//  Created by Design System on 2025-02-11.
//  午夜幽蓝主题
//

import SwiftUI

// MARK: - 午夜幽蓝主题
///
/// 深邃的午夜蓝调，神秘而宁静。
/// 特点：蓝紫色调，赛博朋克风格
///
struct MidnightTheme: ThemeProtocol {
    // MARK: - 主题信息

    let identifier = "midnight"
    let displayName = "午夜幽蓝"
    let compactName = "午夜"
    let description = "深邃的午夜蓝调，神秘而宁静"
    let iconName = "moon.stars.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "5B4FCF")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "5B4FCF"),  // 午夜蓝紫
            secondary: SwiftUI.Color(hex: "7C6FFF"), // 紫罗兰
            tertiary: SwiftUI.Color(hex: "00D4FF")   // 赛博蓝
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "050510"),     // 深邃午夜
            medium: SwiftUI.Color(hex: "0A0A1F"),   // 中层夜色
            light: SwiftUI.Color(hex: "151530")     // 浅层夜光
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "7C6FFF").opacity(0.3),
            medium: SwiftUI.Color(hex: "7C6FFF").opacity(0.5),
            intense: SwiftUI.Color(hex: "00D4FF").opacity(0.7)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                // 深邃背景
                backgroundGradient()
                    .ignoresSafeArea()

                // 主光晕 (左上)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.4),
                                accentColors().primary.opacity(0.1),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 400
                        )
                    )
                    .frame(width: 800, height: 800)
                    .blur(radius: 100)
                    .offset(x: -200, y: -200)

                // 次光晕 (右下 - 赛博蓝)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.3))
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height)
                
                // 氛围点缀 (右上 - 紫罗兰)
                Circle()
                    .fill(accentColors().secondary.opacity(0.2))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .position(x: proxy.size.width, y: 0)
                
                // 背景图标点缀
                ZStack {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 300))
                        .foregroundStyle(accentColors().primary.opacity(0.05))
                        .rotationEffect(.degrees(-15))
                        .offset(x: proxy.size.width * 0.3, y: -proxy.size.height * 0.2)
                        .blur(radius: 5)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(accentColors().tertiary.opacity(0.1))
                        .offset(x: -proxy.size.width * 0.3, y: proxy.size.height * 0.3)
                        .blur(radius: 3)
                }
            }
        )
    }
}
