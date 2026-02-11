//
//  ColorTokens.swift
//  Lumi
//
//  Created by Design System on 2025-02-11.
//  设计令牌 - 颜色系统
//

import SwiftUI

// MARK: - 颜色系统
///
/// 定义应用中所有颜色相关的设计令牌。
/// 包括基础色板、语义化颜色和渐变色。
///
extension DesignTokens {
    enum Color {
        // MARK: - 基础色板
        /// 基础色调（神秘深色）
        static let basePalette = BasePalette()

        /// 语义化颜色
        static let semantic = SemanticColors()

        /// 渐变色
        static let gradients = GradientColors()

        // MARK: - 基础色调
        /// 基础色调 - 定义应用的基础背景和氛围色
        struct BasePalette {
            // 深色背景（OLED 优化）
            let deepBackground = SwiftUI.Color(hex: "050508")      // 接近纯黑，带神秘蓝调
            let surfaceBackground = SwiftUI.Color(hex: "0D0D12")   // 卡片表面
            let elevatedSurface = SwiftUI.Color(hex: "14141A")     // 悬浮表面
            let overlayBackground = SwiftUI.Color(hex: "1A1A22")   // 叠加层

            // 神秘氛围色
            let mysticIndigo = SwiftUI.Color(hex: "1E1B2E")       // 靛紫
            let mysticViolet = SwiftUI.Color(hex: "2D1B3D")       // 紫罗兰
            let mysticAzure = SwiftUI.Color(hex: "0B1A2E")         // 深蔚蓝

            // 高光和边框
            let subtleBorder = SwiftUI.Color(hex: "FFFFFF")        // 微妙白边
            let glowAccent = SwiftUI.Color(hex: "6B5CE7")         // 幽光紫
        }

        // MARK: - 语义化颜色
        /// 语义化颜色 - 具有特定含义的颜色
        struct SemanticColors {
            // 主色调
            let primary = SwiftUI.Color(hex: "7C6FFF")             // 主紫
            let primarySecondary = SwiftUI.Color(hex: "A99CFF")    // 次紫

            // 状态色
            let success = SwiftUI.Color(hex: "30D158")             // 成功绿
            let successGlow = SwiftUI.Color(hex: "7CFFB5")         // 成功光晕
            let warning = SwiftUI.Color(hex: "FF9F0A")             // 警告橙
            let warningGlow = SwiftUI.Color(hex: "FFD57F")         // 警告光晕
            let error = SwiftUI.Color(hex: "FF453A")               // 错误红
            let errorGlow = SwiftUI.Color(hex: "FF7A73")           // 错误光晕
            let info = SwiftUI.Color(hex: "0A84FF")                // 信息蓝
            let infoGlow = SwiftUI.Color(hex: "7AB8FF")            // 信息光晕

            // 文本色（确保 WCAG AA 对比度 ≥ 4.5:1）
            let textPrimary = SwiftUI.Color(hex: "FFFFFF")         // 主要文本 100%
            let textSecondary = SwiftUI.Color(hex: "EBEBF5")       // 次要文本 92%
            let textTertiary = SwiftUI.Color(hex: "98989E")        // 三级文本 60%
            let textDisabled = SwiftUI.Color(hex: "48484F")        // 禁用文本 28%
        }

        // MARK: - 渐变色
        /// 渐变色 - 预定义的渐变效果
        struct GradientColors {
            // 主渐变（神秘紫）
            var primaryGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "7C6FFF"),
                    SwiftUI.Color(hex: "B4A5FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 深海渐变
            var oceanGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "0A1A3E"),
                    SwiftUI.Color(hex: "1A2A5E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 极光渐变
            var auroraGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "6B5CE7"),
                    SwiftUI.Color(hex: "A78BFA"),
                    SwiftUI.Color(hex: "38BDF8")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 能量渐变（用于进度、活跃状态）
            var energyGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "00D4FF"),
                    SwiftUI.Color(hex: "7C6FFF")
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // 发光边框渐变
            var glowBorderGradient = LinearGradient(
                colors: [
                    SwiftUI.Color.clear,
                    SwiftUI.Color.white.opacity(0.08),
                    SwiftUI.Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
