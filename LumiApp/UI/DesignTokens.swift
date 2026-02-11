import SwiftUI

// MARK: - 设计令牌命名空间
///
/// 设计令牌是设计系统的核心，定义了所有视觉和交互参数的统一标准。
/// 使用这些令牌确保整个应用的视觉一致性。
///
enum DesignTokens {}

// MARK: - 颜色系统
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

// MARK: - 间距系统
extension DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4      // 超小间距
        static let sm: CGFloat = 8      // 小间距
        static let md: CGFloat = 16     // 中等间距
        static let lg: CGFloat = 24     // 大间距
        static let xl: CGFloat = 32     // 超大间距
        static let xxl: CGFloat = 48    // 特大间距

        // 组件内边距
        static let cardPadding = EdgeInsets(
            top: md,
            leading: md,
            bottom: md,
            trailing: md
        )

        static let compactPadding = EdgeInsets(
            top: sm,
            leading: sm,
            bottom: sm,
            trailing: sm
        )

        static let comfortablePadding = EdgeInsets(
            top: lg,
            leading: lg,
            bottom: lg,
            trailing: lg
        )
    }
}

// MARK: - 圆角系统
extension DesignTokens {
    enum Radius {
        static let sm: CGFloat = 8      // 小圆角（按钮、标签）
        static let md: CGFloat = 16     // 中圆角（卡片）
        static let lg: CGFloat = 24     // 大圆角（模态、面板）
        static let xl: CGFloat = 32     // 超大圆角（特殊容器）
        static let full: CGFloat = .infinity  // 完全圆角（药丸形状）
    }
}

// MARK: - 阴影系统
extension DesignTokens {
    enum Shadow {
        // 微妙阴影（用于卡片）
        static let subtle = SwiftUI.Color.black.opacity(0.15)
        static let subtleRadius: CGFloat = 12
        static let subtleOffset: CGFloat = 4

        // 发光阴影（用于强调元素）
        static func glow(color: SwiftUI.Color, radius: CGFloat = 8) -> SwiftUI.Color {
            color.opacity(0.4)
        }

        // 深度阴影（用于浮动元素）
        static let deep = SwiftUI.Color.black.opacity(0.25)
        static let deepRadius: CGFloat = 20
        static let deepOffset: CGFloat = 8
    }
}

// MARK: - 字体系统
extension DesignTokens {
    enum Typography {
        // 标题字体
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .semibold)
        static let title3 = Font.system(size: 20, weight: .semibold)

        // 正文字体
        static let body = Font.system(size: 15, weight: .regular)
        static let bodyEmphasized = Font.system(size: 15, weight: .medium)
        static let subheadline = Font.system(size: 13, weight: .regular)
        static let callout = Font.system(size: 16, weight: .medium)

        // 小字体
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption1 = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
    }
}

// MARK: - 动画时长
extension DesignTokens {
    enum Duration {
        static let micro: TimeInterval = 0.15      // 微交互
        static let standard: TimeInterval = 0.20   // 标准过渡
        static let moderate: TimeInterval = 0.30   // 中等动画
        static let slow: TimeInterval = 0.50       // 缓慢动画
    }
}

// MARK: - 材质系统
extension DesignTokens {
    enum Material {
        // 玻璃态材质
        static let glass = SwiftUI.Material.ultraThinMaterial
        static let glassThick = SwiftUI.Material.thinMaterial
        static let glassThin = SwiftUI.Material.ultraThinMaterial

        // 神秘氛围材质（带深色叠加）
        static func mysticGlass(opacity: Double = 0.3) -> some ShapeStyle {
            SwiftUI.Color.black.opacity(opacity)
        }
    }
}

// 注意：Color(hex:) 扩展已在 Core/Theme/AppTheme.swift 中定义，这里不再重复定义

// MARK: - 预览
#Preview("颜色系统") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ColorSwatch(name: "深背景", color: DesignTokens.Color.basePalette.deepBackground)
            ColorSwatch(name: "表面", color: DesignTokens.Color.basePalette.surfaceBackground)
            ColorSwatch(name: "靛紫", color: DesignTokens.Color.basePalette.mysticIndigo)
            ColorSwatch(name: "幽光", color: DesignTokens.Color.basePalette.glowAccent)
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            ColorSwatch(name: "主紫", color: DesignTokens.Color.semantic.primary)
            ColorSwatch(name: "成功", color: DesignTokens.Color.semantic.success)
            ColorSwatch(name: "警告", color: DesignTokens.Color.semantic.warning)
            ColorSwatch(name: "错误", color: DesignTokens.Color.semantic.error)
        }

        GradientSwatch(name: "主渐变", gradient: DesignTokens.Color.gradients.primaryGradient)
        GradientSwatch(name: "极光", gradient: DesignTokens.Color.gradients.auroraGradient)
    }
    .padding(DesignTokens.Spacing.lg)
    .background(DesignTokens.Color.basePalette.deepBackground)
}

private struct ColorSwatch: View {
    let name: String
    let color: SwiftUI.Color

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 50, height: 50)
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }
}

private struct GradientSwatch: View {
    let name: String
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(gradient)
                .frame(height: 50)
            Text(name)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }
}
