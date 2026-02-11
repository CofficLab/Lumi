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
}
