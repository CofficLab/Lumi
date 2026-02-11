//
//  NebulaTheme.swift
//  Lumi
//
//  Created by Design System on 2025-02-11.
//  星云粉主题
//

import SwiftUI

// MARK: - 星云粉主题
///
/// 浪漫的星云粉，柔和而温暖。
/// 特点：粉紫色调，温馨浪漫
///
struct NebulaTheme: ThemeProtocol {
    // MARK: - 主题信息

    let identifier = "nebula"
    let displayName = "星云粉"
    let compactName = "星云"
    let description = "浪漫的星云粉，柔和而温暖"
    let iconName = "cloud.moon.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "F472B6")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "F472B6"),  // 星云粉
            secondary: SwiftUI.Color(hex: "FB7185"), // 玫瑰红
            tertiary: SwiftUI.Color(hex: "C084FC")  // 星云紫
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "10050A"),     // 星云深邃
            medium: SwiftUI.Color(hex: "1F0A15"),   // 星云中层
            light: SwiftUI.Color(hex: "301020")     // 星云浅层
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "F472B6").opacity(0.3),
            medium: SwiftUI.Color(hex: "FB7185").opacity(0.5),
            intense: SwiftUI.Color(hex: "C084FC").opacity(0.7)
        )
    }
}
