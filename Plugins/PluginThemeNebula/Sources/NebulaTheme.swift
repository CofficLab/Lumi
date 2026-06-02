//
//  NebulaTheme.swift
//  Lumi
//
//  Created by Design System on 2025-02-11.
//  星云粉主题
//

import SwiftUI
import LumiUI

// MARK: - 星云粉主题
///
/// 浪漫的星云粉，柔和而温暖。
/// 特点：粉紫色调，温馨浪漫
///
public struct NebulaTheme: LumiAppChromeTheme {
    // MARK: - 主题信息

    public let identifier = "nebula"
    public let displayName = "星云粉"
    public let compactName = "星云"
    public let description = "浪漫的星云粉，柔和而温暖"
    public let iconName = "cloud.moon.fill"
    public let appearanceKind: ThemeAppearanceKind = .dark

    public init() {}

    public var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "DB2777", dark: "F472B6")
    }

    // MARK: - 颜色配置

    public func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color.adaptive(light: "DB2777", dark: "F472B6"),  // 星云粉 (浅色稍深)
            secondary: SwiftUI.Color.adaptive(light: "E11D48", dark: "FB7185"), // 玫瑰红
            tertiary: SwiftUI.Color.adaptive(light: "9333EA", dark: "C084FC")   // 星云紫
        )
    }

    public func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color.adaptive(light: "FFF0F5", dark: "10050A"),      // 背景：浅粉白 vs 深红黑
            medium: SwiftUI.Color.adaptive(light: "FFFFFF", dark: "1F0A15"),     // 卡片
            light: SwiftUI.Color.adaptive(light: "FFE4E9", dark: "301020")       // 高光
        )
    }

    public func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color.adaptive(light: "DB2777", dark: "F472B6").opacity(0.3),
            medium: SwiftUI.Color.adaptive(light: "E11D48", dark: "FB7185").opacity(0.5),
            intense: SwiftUI.Color.adaptive(light: "9333EA", dark: "C084FC").opacity(0.7)
        )
    }

    public func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                backgroundGradient()
                    .ignoresSafeArea()

                // 星云云团 1 (粉色)
                Circle()
                    .fill(accentColors().primary.opacity(0.2))
                    .frame(width: 500, height: 500)
                    .blur(radius: 80)
                    .offset(x: -150, y: 100)
                    .overlay(
                        Circle()
                            .stroke(accentColors().primary.opacity(0.1), lineWidth: 50)
                            .blur(radius: 50)
                    )

                // 星云云团 2 (紫色)
                Circle()
                    .fill(accentColors().tertiary.opacity(0.25))
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.3)

                // 星云云团 3 (玫瑰红)
                Circle()
                    .fill(accentColors().secondary.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .position(x: proxy.size.width * 0.2, y: proxy.size.height * 0.8)

                // 背景图标点缀
                ZStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 350))
                        .foregroundStyle(accentColors().primary.opacity(0.03))
                        .offset(x: -proxy.size.width * 0.1, y: -proxy.size.height * 0.15)
                        .blur(radius: 8)

                    Image(systemName: "sparkle")
                        .font(.system(size: 150))
                        .foregroundStyle(accentColors().tertiary.opacity(0.08))
                        .offset(x: proxy.size.width * 0.35, y: proxy.size.height * 0.25)
                        .blur(radius: 2)
                }
            }
        )
    }
}
