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
/// 现在支持浅色/深色模式自动适配。
///
extension DesignTokens {
    enum Color {
        // MARK: - 响应式颜色（支持浅色/深色模式）
        /// 响应式语义化颜色 - 根据 ColorScheme 自动适配
        /// 使用 @Environment(\.colorScheme) 获取当前配色方案
        static let adaptive = AdaptiveSemanticColors()

        // MARK: - 基础色板（保持向后兼容）
        /// 基础色调（森林墨 · 暖中性深色）
        static let basePalette = BasePalette()

        /// 语义化颜色（静态，仅用于深色模式）
        /// ⚠️ 建议使用 adaptive 替代
        static let semantic = SemanticColors()

        /// 渐变色
        static let gradients = GradientColors()

        // MARK: - 基础色调
        /// 基础色调 - 定义应用的基础背景和氛围色（森林墨 · 暖中性纸墨底）
        struct BasePalette {
            // 深色背景（暖墨调，OLED 友好）
            let deepBackground = SwiftUI.Color(hex: "1C1C1A")      // 暖墨：接近黑，带微暖底
            let surfaceBackground = SwiftUI.Color(hex: "262624")   // 卡片表面
            let elevatedSurface = SwiftUI.Color(hex: "30302E")     // 悬浮表面
            let overlayBackground = SwiftUI.Color(hex: "383835")   // 叠加层

            // 森林氛围色（保留原属性名，值已重映色）
            let mysticIndigo = SwiftUI.Color(hex: "1A2A22")        // 苔墨（原靛紫位）
            let mysticViolet = SwiftUI.Color(hex: "1F3329")        // 深林（原紫罗兰位）
            let mysticAzure = SwiftUI.Color(hex: "0B2228")         // 深青墨（原深蔚蓝位）

            // 高光和边框
            let subtleBorder = SwiftUI.Color(hex: "FFFFFF")        // 微妙白边
            let glowAccent = SwiftUI.Color(hex: "10B981")          // 墨翠幽光
        }

        // MARK: - 语义化颜色
        /// 语义化颜色 - 具有特定含义的颜色
        struct SemanticColors {
            // 主色调（森林墨）
            let primary = SwiftUI.Color.adaptive(light: "059669", dark: "34D399")             // 墨翠
            let primarySecondary = SwiftUI.Color.adaptive(light: "D97706", dark: "F59E0B")    // 赭石

            // 状态色
            let success = SwiftUI.Color.adaptive(light: "30D158", dark: "30D158")             // 成功绿
            let successGlow = SwiftUI.Color.adaptive(light: "7CFFB5", dark: "7CFFB5")         // 成功光晕
            let warning = SwiftUI.Color.adaptive(light: "FF9F0A", dark: "FF9F0A")             // 警告橙
            let warningGlow = SwiftUI.Color.adaptive(light: "FFD57F", dark: "FFD57F")         // 警告光晕
            let error = SwiftUI.Color.adaptive(light: "FF453A", dark: "FF453A")               // 错误红
            let errorGlow = SwiftUI.Color.adaptive(light: "FF7A73", dark: "FF7A73")           // 错误光晕
            let info = SwiftUI.Color.adaptive(light: "0EA5E9", dark: "38BDF8")                // 信息天青
            let infoGlow = SwiftUI.Color.adaptive(light: "7DD3FC", dark: "7DD3FC")            // 信息光晕

            // 文本色（暖中性 stone，确保 WCAG AA 对比度 ≥ 4.5:1）
            let textPrimary = SwiftUI.Color.adaptive(light: "1C1917", dark: "FAFAF9")         // 主要文本
            let textSecondary = SwiftUI.Color.adaptive(light: "57534E", dark: "D6D3D1")       // 次要文本
            let textTertiary = SwiftUI.Color.adaptive(light: "A8A29E", dark: "A8A29E")        // 三级文本
            let textDisabled = SwiftUI.Color.adaptive(light: "BDBDBD", dark: "48484F")        // 禁用文本
        }

        // MARK: - 渐变色
        /// 渐变色 - 预定义的渐变效果
        struct GradientColors {
            // 主渐变（墨翠 → 赭石，森林泥土气质）
            var primaryGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "059669"),
                    SwiftUI.Color(hex: "D97706")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 深海渐变（墨青 → 深林）
            var oceanGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "0B2228"),
                    SwiftUI.Color(hex: "1F3329")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 极光渐变（墨翠 → 赭石 → 天青，森林暮色）
            var auroraGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "10B981"),
                    SwiftUI.Color(hex: "D97706"),
                    SwiftUI.Color(hex: "0EA5E9")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 能量渐变（用于进度、活跃状态：天青 → 墨翠）
            var energyGradient = LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "0EA5E9"),
                    SwiftUI.Color(hex: "059669")
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

    // MARK: - 响应式语义化颜色
    /// 响应式语义化颜色 - 根据 ColorScheme 自动适配
    /// 提供动态颜色选择，支持浅色和深色模式
    struct AdaptiveSemanticColors {
        // MARK: - 环境依赖的颜色计算

        /// 主要文本色（根据配色方案动态调整）
        func textPrimary(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "1C1917")  // 深墨文本（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "FAFAF9")  // 暖纸文本（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "FAFAF9")
            }
        }

        /// 次要文本色
        func textSecondary(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "57534E")  // 暖灰文本（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "D6D3D1")  // 浅暖文本（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "D6D3D1")
            }
        }

        /// 三级文本色
        func textTertiary(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light, .dark:
                SwiftUI.Color(hex: "A8A29E")  // 暖灰文本（两种模式都可用）
            @unknown default:
                SwiftUI.Color(hex: "A8A29E")
            }
        }

        /// 禁用文本色
        func textDisabled(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "BDBDBD")  // 浅灰（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "48484F")  // 深灰（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "48484F")
            }
        }

        // MARK: - 背景色

        /// 深色背景色
        func deepBackground(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "FAFAF9")  // 暖纸背景（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "1C1C1A")  // 暖墨背景（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "1C1C1A")
            }
        }

        /// 卡片表面背景色
        func surfaceBackground(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "FFFFFF")  // 纯白卡片（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "262624")  // 暖墨卡片（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "262624")
            }
        }

        /// 悬浮表面背景色
        func elevatedSurface(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "E7E5E4")  // 暖灰悬浮（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "30302E")  // 悬浮暖墨（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "30302E")
            }
        }

        /// 叠加层背景色
        func overlayBackground(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "E7E5E4")  // 暖灰叠加（浅色模式）
            case .dark:
                SwiftUI.Color(hex: "383835")  // 暖墨叠加（深色模式）
            @unknown default:
                SwiftUI.Color(hex: "383835")
            }
        }

        /// 分隔线颜色
        func divider(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "E7E5E4").opacity(0.5)  // 暖灰分隔线
            case .dark:
                SwiftUI.Color(hex: "FFFFFF").opacity(0.15)  // 白色分隔线
            @unknown default:
                SwiftUI.Color(hex: "FFFFFF").opacity(0.15)
            }
        }

        // MARK: - 主题色（森林墨）

        /// 主色调
        let primary = SwiftUI.Color.adaptive(light: "059669", dark: "34D399")
        let primarySecondary = SwiftUI.Color.adaptive(light: "D97706", dark: "F59E0B")

        /// 主渐变（墨翠 → 赭石）
        func primaryGradient(for scheme: ColorScheme) -> LinearGradient {
            // 两种模式使用相同的主题渐变，保持品牌一致性
            LinearGradient(
                colors: [
                    SwiftUI.Color(hex: "059669"),
                    SwiftUI.Color(hex: "D97706")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// 错误红（根据配色方案调整）
        func error(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "FF3B30")  // 浅色模式：更醒目的红色
            case .dark:
                SwiftUI.Color(hex: "FF453A")  // 深色模式：系统错误红
            @unknown default:
                SwiftUI.Color(hex: "FF453A")
            }
        }

        /// 错误色背景（用于危险按钮等）
        func errorBackground(for scheme: ColorScheme) -> SwiftUI.Color {
            switch scheme {
            case .light:
                SwiftUI.Color(hex: "FF3B30").opacity(0.1)  // 浅色模式：浅红背景
            case .dark:
                SwiftUI.Color(hex: "FF453A").opacity(0.2)  // 深色模式：深红背景
            @unknown default:
                SwiftUI.Color(hex: "FF453A").opacity(0.2)
            }
        }

        // 状态色
        let success = SwiftUI.Color(hex: "30D158")
        let successGlow = SwiftUI.Color(hex: "7CFFB5")
        let warning = SwiftUI.Color(hex: "FF9F0A")
        let warningGlow = SwiftUI.Color(hex: "FFD57F")
        let error = SwiftUI.Color(hex: "FF453A")
        let errorGlow = SwiftUI.Color(hex: "FF7A73")
        let info = SwiftUI.Color(hex: "0EA5E9")
        let infoGlow = SwiftUI.Color(hex: "7DD3FC")

        // MARK: - 材质效果

        /// 氛围玻璃材质（根据模式调整透明度）
        func mysticGlassMaterial(for scheme: ColorScheme) -> some ShapeStyle {
            switch scheme {
            case .light:
                SwiftUI.Color.white.opacity(0.7)  // 浅色模式：白色半透明
            case .dark:
                SwiftUI.Color.black.opacity(0.3)  // 深色模式：黑色半透明
            @unknown default:
                SwiftUI.Color.black.opacity(0.3)
            }
        }

        /// 光晕强度（根据模式调整）
        func glowIntensity(for scheme: ColorScheme) -> Double {
            switch scheme {
            case .light:
                return 0.06  // 浅色模式：较弱的光晕（避免过度曝光）
            case .dark:
                return 0.15  // 深色模式：正常光晕
            @unknown default:
                return 0.15
            }
        }

        /// 边框透明度
        func borderOpacity(for scheme: ColorScheme) -> Double {
            switch scheme {
            case .light:
                return 0.3  // 浅色模式：较淡的边框
            case .dark:
                return 0.15  // 深色模式：标准边框
            @unknown default:
                return 0.15
            }
        }
    }
}
