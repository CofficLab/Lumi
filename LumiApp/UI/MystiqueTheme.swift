import SwiftUI

// MARK: - 神秘感主题
///
/// 神秘感主题系统，为应用增添神秘的视觉氛围。
/// 包含：微光效果、粒子动画、极光渐变、神秘光晕等。
///
enum MystiqueTheme {
    // MARK: - 主题变体
    enum Variant {
        case midnight   // 午夜幽蓝
        case aurora     // 极光紫
        case nebula     // 星云粉
        case void       // 虚空深黑
    }

    // MARK: - 主题配置
    nonisolated(unsafe) static var currentVariant: Variant = .midnight {
        didSet {
            updateTheme()
        }
    }

    nonisolated(unsafe) static var isHighContrast: Bool = false
    nonisolated(unsafe) static var isReducedMotion: Bool = false

    // MARK: - 颜色配置
    enum Colors {
        // 主色调
        static let accent = AccentColors()

        // 氛围色
        static let atmosphere = AtmosphereColors()

        // 光晕色
        static let glow = GlowColors()
    }

    // MARK: - 强调色
    struct AccentColors {
        let primary: SwiftUI.Color
        let secondary: SwiftUI.Color
        let tertiary: SwiftUI.Color

        init(variant: Variant = currentVariant) {
            switch variant {
            case .midnight:
                primary = SwiftUI.Color(hex: "5B4FCF")  // 午夜蓝紫
                secondary = SwiftUI.Color(hex: "7C6FFF") // 紫罗兰
                tertiary = SwiftUI.Color(hex: "00D4FF")  // 赛博蓝
            case .aurora:
                primary = SwiftUI.Color(hex: "A78BFA")   // 极光紫
                secondary = SwiftUI.Color(hex: "38BDF8") // 天空蓝
                tertiary = SwiftUI.Color(hex: "34D399")  // 极光绿
            case .nebula:
                primary = SwiftUI.Color(hex: "F472B6")   // 星云粉
                secondary = SwiftUI.Color(hex: "FB7185") // 玫瑰红
                tertiary = SwiftUI.Color(hex: "C084FC")  // 星云紫
            case .void:
                primary = SwiftUI.Color(hex: "6366F1")   // 虚空靛
                secondary = SwiftUI.Color(hex: "8B5CF6") // 虚空紫
                tertiary = SwiftUI.Color(hex: "EC4899")  // 虚空粉
            }
        }
    }

    // MARK: - 氛围色
    struct AtmosphereColors {
        let deep: SwiftUI.Color
        let medium: SwiftUI.Color
        let light: SwiftUI.Color

        init(variant: Variant = currentVariant) {
            switch variant {
            case .midnight:
                deep = SwiftUI.Color(hex: "050510")     // 深邃午夜
                medium = SwiftUI.Color(hex: "0A0A1F")   // 中层夜色
                light = SwiftUI.Color(hex: "151530")    // 浅层夜光
            case .aurora:
                deep = SwiftUI.Color(hex: "0A0515")     // 极光深邃
                medium = SwiftUI.Color(hex: "120A20")   // 极光中层
                light = SwiftUI.Color(hex: "1F1535")    // 极光浅层
            case .nebula:
                deep = SwiftUI.Color(hex: "10050A")     // 星云深邃
                medium = SwiftUI.Color(hex: "1F0A15")   // 星云中层
                light = SwiftUI.Color(hex: "301020")    // 星云浅层
            case .void:
                deep = SwiftUI.Color(hex: "020205")     // 虚空之深
                medium = SwiftUI.Color(hex: "080810")   // 虚空中层
                light = SwiftUI.Color(hex: "101018")    // 虚空浅层
            }
        }
    }

    // MARK: - 光晕色
    struct GlowColors {
        let subtle: SwiftUI.Color
        let medium: SwiftUI.Color
        let intense: SwiftUI.Color

        init(variant: Variant = currentVariant) {
            switch variant {
            case .midnight:
                subtle = SwiftUI.Color(hex: "7C6FFF").opacity(0.3)
                medium = SwiftUI.Color(hex: "7C6FFF").opacity(0.5)
                intense = SwiftUI.Color(hex: "00D4FF").opacity(0.7)
            case .aurora:
                subtle = SwiftUI.Color(hex: "A78BFA").opacity(0.3)
                medium = SwiftUI.Color(hex: "38BDF8").opacity(0.5)
                intense = SwiftUI.Color(hex: "34D399").opacity(0.7)
            case .nebula:
                subtle = SwiftUI.Color(hex: "F472B6").opacity(0.3)
                medium = SwiftUI.Color(hex: "FB7185").opacity(0.5)
                intense = SwiftUI.Color(hex: "C084FC").opacity(0.7)
            case .void:
                subtle = SwiftUI.Color(hex: "6366F1").opacity(0.3)
                medium = SwiftUI.Color(hex: "8B5CF6").opacity(0.5)
                intense = SwiftUI.Color(hex: "EC4899").opacity(0.7)
            }
        }
    }

    // MARK: - 渐变配置
    enum Gradients {
        /// 极光背景渐变
        static var auroraBackground: LinearGradient {
            LinearGradient(
                colors: [
                    MystiqueTheme.Colors.atmosphere.deep,
                    MystiqueTheme.Colors.atmosphere.medium,
                    MystiqueTheme.Colors.atmosphere.light,
                    MystiqueTheme.Colors.atmosphere.medium,
                    MystiqueTheme.Colors.atmosphere.deep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// 神秘光晕渐变
        static var mysticGlow: RadialGradient {
            RadialGradient(
                colors: [
                    MystiqueTheme.Colors.glow.intense,
                    MystiqueTheme.Colors.glow.medium,
                    MystiqueTheme.Colors.glow.subtle,
                    SwiftUI.Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
        }

        /// 能量流动渐变
        static var energyFlow: LinearGradient {
            LinearGradient(
                colors: [
                    MystiqueTheme.Colors.accent.primary,
                    MystiqueTheme.Colors.accent.secondary,
                    MystiqueTheme.Colors.accent.tertiary
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        /// 神秘边框渐变
        static var mysticBorder: LinearGradient {
            LinearGradient(
                colors: [
                    SwiftUI.Color.clear,
                    MystiqueTheme.Colors.glow.subtle,
                    SwiftUI.Color.white.opacity(0.1),
                    MystiqueTheme.Colors.glow.subtle,
                    SwiftUI.Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - 效果配置
    enum Effects {
        /// 光晕强度
        static let glowRadius: CGFloat = 20
        static let glowIntensity: Double = 0.4

        /// 脉冲动画配置
        static let pulseDuration: TimeInterval = 3.0
        static let pulseMinScale: CGFloat = 0.95
        static let pulseMaxScale: CGFloat = 1.05

        /// 微光配置
        static let shimmerSpeed: Double = 0.15
        static let shimmerDuration: TimeInterval = 2.0
    }

    // MARK: - 主题更新
    private static func updateTheme() {
        // 主题切换时的处理
        // 可以在这里发送通知或触发回调
    }
}

// MARK: - 神秘背景视图
///
/// 带有神秘氛围的背景视图
///
struct MystiqueBackground: View {
    let variant: MystiqueTheme.Variant
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 基础背景
            MystiqueTheme.Gradients.auroraBackground
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: variant)

            // 氛围光晕
            glowOrbs
                .opacity(isAnimating ? 1 : 0.5)
                .animation(
                    .easeInOut(duration: MystiqueTheme.Effects.pulseDuration)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }

    @ViewBuilder private var glowOrbs: some View {
        ZStack {
            // 主光晕
            Circle()
                .fill(MystiqueTheme.Gradients.mysticGlow)
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -100)
                .blur(radius: 60)

            // 次光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MystiqueTheme.Colors.glow.medium,
                            SwiftUI.Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 100)
                .blur(radius: 50)
        }
    }
}

// MARK: - 微光效果视图
///
/// 神秘的微光扫过效果
///
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    let duration: TimeInterval
    let blur: CGFloat

    init(duration: TimeInterval = 2.0, blur: CGFloat = 20) {
        self.duration = duration
        self.blur = blur
    }

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    SwiftUI.Color.clear,
                    SwiftUI.Color.white.opacity(0.3),
                    SwiftUI.Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.5)
            .offset(x: phase * geometry.size.width * 1.5 - geometry.size.width)
            .blur(radius: blur)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - 脉冲光晕视图
///
/// 神秘的脉冲光晕效果
///
struct PulsingGlowView: View {
    let color: SwiftUI.Color
    let duration: TimeInterval
    let minScale: CGFloat
    let maxScale: CGFloat

    @State private var isPulsing = false

    init(
        color: SwiftUI.Color = MystiqueTheme.Colors.glow.intense,
        duration: TimeInterval = MystiqueTheme.Effects.pulseDuration,
        minScale: CGFloat = MystiqueTheme.Effects.pulseMinScale,
        maxScale: CGFloat = MystiqueTheme.Effects.pulseMaxScale
    ) {
        self.color = color
        self.duration = duration
        self.minScale = minScale
        self.maxScale = maxScale
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0.2),
                        SwiftUI.Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 100
                )
            )
            .scaleEffect(isPulsing ? maxScale : minScale)
            .opacity(isPulsing ? 0.8 : 0.4)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - View 扩展
extension View {
    /// 应用神秘主题背景
    func mystiqueBackground(variant: MystiqueTheme.Variant = .midnight) -> some View {
        self.background(MystiqueBackground(variant: variant))
    }

    /// 添加微光效果
    func shimmer(
        isActive: Bool = true,
        duration: TimeInterval = MystiqueTheme.Effects.shimmerDuration,
        blur: CGFloat = 20
    ) -> some View {
        self.overlay(
            Group {
                if isActive {
                    ShimmerView(duration: duration, blur: blur)
                }
            }
        )
    }

    /// 添加脉冲光晕
    func pulsingGlow(
        color: SwiftUI.Color = MystiqueTheme.Colors.glow.intense,
        duration: TimeInterval = MystiqueTheme.Effects.pulseDuration
    ) -> some View {
        self.background(
            PulsingGlowView(color: color, duration: duration)
        )
    }

    /// 应用神秘光晕效果
    func mystiqueGlow(
        intensity: Double = MystiqueTheme.Effects.glowIntensity
    ) -> some View {
        self.glowEffect(
            color: MystiqueTheme.Colors.glow.medium,
            radius: MystiqueTheme.Effects.glowRadius,
            intensity: intensity
        )
    }

    /// 神秘边框
    func mystiqueBorder(cornerRadius: CGFloat = DesignTokens.Radius.md) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(MystiqueTheme.Gradients.mysticBorder, lineWidth: 1.5)
        )
    }
}

// MARK: - 主题切换器（用于预览和设置）
@MainActor
class MystiqueThemeManager: ObservableObject {
    @Published var currentVariant: MystiqueTheme.Variant {
        didSet {
            // 更新全局主题
            MystiqueTheme.currentVariant = currentVariant
            // 保存用户选择
            currentVariant.save()
            // 触发更新
            updateColors()
        }
    }

    @Published var isHighContrast: Bool = false {
        didSet {
            MystiqueTheme.isHighContrast = isHighContrast
        }
    }

    /// 初始化主题管理器，加载保存的主题
    init() {
        // 从 UserDefaults 加载保存的主题
        self.currentVariant = MystiqueTheme.Variant.loadSaved()
        // 应用加载的主题
        MystiqueTheme.currentVariant = currentVariant
    }

    private func updateColors() {
        // 更新主题时会自动刷新
        objectWillChange.send()
    }
}

// MARK: - 预览
#Preview("神秘主题背景") {
    VStack {
        Text("神秘主题")
            .font(DesignTokens.Typography.largeTitle)
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

        Text("午夜幽蓝氛围")
            .font(DesignTokens.Typography.body)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }
    .mystiqueBackground(variant: .midnight)
}

#Preview("微光效果") {
    GlassCard {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("微光效果卡片")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("神秘的微光会从左到右扫过，创造出梦幻的视觉效果")
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }
    .frame(width: 300)
    .shimmer(isActive: true)
    .padding(DesignTokens.Spacing.lg)
    .background(DesignTokens.Color.basePalette.deepBackground)
}

#Preview("脉冲光晕") {
    ZStack {
        DesignTokens.Color.basePalette.deepBackground.ignoresSafeArea()

        VStack(spacing: DesignTokens.Spacing.xl) {
            PulsingGlowView(color: MystiqueTheme.Colors.glow.intense)
                .frame(width: 100, height: 100)

            PulsingGlowView(color: DesignTokens.Color.semantic.success)
                .frame(width: 80, height: 80)

            PulsingGlowView(color: DesignTokens.Color.semantic.error)
                .frame(width: 60, height: 60)
        }
    }
}

#Preview("主题变体") {
    ScrollView(.vertical) {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ForEach([MystiqueTheme.Variant.midnight, .aurora, .nebula, .void], id: \.self) { variant in
                GlassCard {
                    HStack {
                        // 使用每个主题的特定颜色
                        ZStack {
                            Circle()
                                .fill(variant.iconColor)
                                .opacity(0.2)
                                .frame(width: 48, height: 48)

                            Image(systemName: variant.iconName)
                                .font(.system(size: 20))
                                .foregroundColor(variant.iconColor)
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(variantName(for: variant))
                                .font(DesignTokens.Typography.bodyEmphasized)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            Text(variant.description)
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        }

                        Spacer()

                        // 色彩示例点
                        Circle()
                            .fill(variant.iconColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .stroke(variant.iconColor, lineWidth: 1)
                        .opacity(0.5)
                )
                .mystiqueGlow(intensity: 0.2)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
    .mystiqueBackground()
    .frame(height: 600)
    .frame(width: 500)
}

private func variantName(for variant: MystiqueTheme.Variant) -> String {
    switch variant {
    case .midnight: return "午夜幽蓝"
    case .aurora: return "极光紫"
    case .nebula: return "星云粉"
    case .void: return "虚空深黑"
    }
}
