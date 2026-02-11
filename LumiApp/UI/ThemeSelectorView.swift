import SwiftUI

// MARK: - 主题选择器
///
/// 用于选择和切换不同的神秘主题
///
struct ThemeSelectorView: View {
    // MARK: - 环境
    @EnvironmentObject private var themeManager: MystiqueThemeManager

    // MARK: - 配置
    var displayMode: DisplayMode = .full
    var showPreview: Bool = true

    // MARK: - 显示模式
    enum DisplayMode {
        case full      // 完整模式（带预览）
        case compact   // 紧凑模式（仅选择器）
        case minimal   // 极简模式（仅图标）
    }

    // MARK: - 主体
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            if displayMode == .full {
                header
            }

            // 主题选择器
            themePicker

            // 预览
            if showPreview && displayMode != .minimal {
                themePreview
            }
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - 标题
    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("主题风格")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Text("选择你喜欢的神秘主题风格")
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
    }

    // MARK: - 主题选择器
    @ViewBuilder
    private var themePicker: some View {
        switch displayMode {
        case .full:
            fullThemePicker
        case .compact:
            compactThemePicker
        case .minimal:
            minimalThemePicker
        }
    }

    // MARK: - 完整主题选择器
    private var fullThemePicker: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: DesignTokens.Spacing.md
        ) {
            ForEach(MystiqueTheme.Variant.allCases, id: \.self) { variant in
                ThemeOptionCard(
                    variant: variant,
                    isSelected: themeManager.currentVariant == variant,
                    action: {
                        withAnimation(DesignAnimations.Preset.bounce) {
                            themeManager.currentVariant = variant
                        }
                    }
                )
            }
        }
    }

    // MARK: - 紧凑主题选择器
    private var compactThemePicker: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(MystiqueTheme.Variant.allCases, id: \.self) { variant in
                ThemeOptionButton(
                    variant: variant,
                    isSelected: themeManager.currentVariant == variant,
                    action: {
                        withAnimation(DesignAnimations.Preset.smoothMove) {
                            themeManager.currentVariant = variant
                        }
                    }
                )
            }
        }
    }

    // MARK: - 极简主题选择器
    private var minimalThemePicker: some View {
        Picker("主题", selection: $themeManager.currentVariant) {
            ForEach(MystiqueTheme.Variant.allCases, id: \.self) { variant in
                Text(variant.displayName(for: .compact))
                    .tag(variant)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 主题预览
    private var themePreview: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("预览效果")
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            PreviewCard(variant: themeManager.currentVariant)
                .frame(height: 100)
        }
    }
}

// MARK: - 主题选项卡片
struct ThemeOptionCard: View {
    let variant: MystiqueTheme.Variant
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // 图标
                themeIcon
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? variant.iconColor : DesignTokens.Color.semantic.textTertiary)

                // 名称
                Text(variant.displayName(for: .full))
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

                // 描述
                Text(variant.description)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
            .background(cardBackground)
            .overlay(cardBorder)
            .cornerRadius(DesignTokens.Radius.md)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(DesignAnimations.Preset.responsive, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var themeIcon: some View {
        Group {
            switch variant {
            case .midnight:
                Image(systemName: "moon.stars.fill")
            case .aurora:
                Image(systemName: "sparkles")
            case .nebula:
                Image(systemName: "cloud.moon.fill")
            case .void:
                Image(systemName: "circle.fill")
            }
        }
    }

    @ViewBuilder private var cardBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(variant.iconColor.opacity(0.15))
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.Material.glass.opacity(0.1))
        }
    }

    @ViewBuilder private var cardBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(variant.iconColor, lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(SwiftUI.Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - 主题选项按钮
struct ThemeOptionButton: View {
    let variant: MystiqueTheme.Variant
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                themeIcon
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? variant.iconColor : DesignTokens.Color.semantic.textTertiary)

                Text(variant.displayName(for: .compact))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textTertiary)
            }
            .frame(width: 60)
            .padding(DesignTokens.Spacing.sm)
            .background(isSelected ? variant.iconColor.opacity(0.15) : SwiftUI.Color.clear)
            .cornerRadius(DesignTokens.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(isSelected ? variant.iconColor : SwiftUI.Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var themeIcon: some View {
        Group {
            switch variant {
            case .midnight:
                Image(systemName: "moon.stars.fill")
            case .aurora:
                Image(systemName: "sparkles")
            case .nebula:
                Image(systemName: "cloud.moon.fill")
            case .void:
                Image(systemName: "circle.fill")
            }
        }
    }
}

// MARK: - 预览卡片
struct PreviewCard: View {
    let variant: MystiqueTheme.Variant

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧：图标
            Circle()
                .fill(variant.iconColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                }

            // 右侧：示例文本
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("预览文本")
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text("这是主题效果的示例")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Material.glass)
        .cornerRadius(DesignTokens.Radius.sm)
        .mystiqueGlow(intensity: 0.2)
    }
}

// MARK: - MystiqueTheme.Variant 扩展
extension MystiqueTheme.Variant {
    /// SF Symbols 图标名称
    var iconName: String {
        switch self {
        case .midnight:
            return "moon.stars.fill"
        case .aurora:
            return "sparkles"
        case .nebula:
            return "cloud.moon.fill"
        case .void:
            return "circle.fill"
        }
    }

    /// 图标颜色
    var iconColor: SwiftUI.Color {
        switch self {
        case .midnight:
            return SwiftUI.Color(hex: "5B4FCF")
        case .aurora:
            return SwiftUI.Color(hex: "A78BFA")
        case .nebula:
            return SwiftUI.Color(hex: "F472B6")
        case .void:
            return SwiftUI.Color(hex: "6366F1")
        }
    }

    /// 显示名称
    func displayName(for style: ThemeSelectorView.DisplayMode) -> LocalizedStringKey {
        switch (self, style) {
        case (.midnight, .full):
            return "午夜幽蓝"
        case (.midnight, .compact), (.midnight, .minimal):
            return "午夜"

        case (.aurora, .full):
            return "极光紫"
        case (.aurora, .compact), (.aurora, .minimal):
            return "极光"

        case (.nebula, .full):
            return "星云粉"
        case (.nebula, .compact), (.nebula, .minimal):
            return "星云"

        case (.void, .full):
            return "虚空深黑"
        case (.void, .compact), (.void, .minimal):
            return "虚空"
        }
    }

    /// 描述
    var description: LocalizedStringKey {
        switch self {
        case .midnight:
            return "深邃的午夜蓝调，神秘而宁静"
        case .aurora:
            return "绚丽的极光紫，梦幻而优雅"
        case .nebula:
            return "浪漫的星云粉，柔和而温暖"
        case .void:
            return "纯粹的虚空黑，深邃而神秘"
        }
    }

    /// 所有主题变体
    static var allCases: [MystiqueTheme.Variant] {
        [.midnight, .aurora, .nebula, .void]
    }

    // MARK: - 持久化

    /// UserDefaults 存储键
    private static let themeKey = "MystiqueTheme.SelectedVariant"

    /// 主题的字符串标识
    var identifier: String {
        switch self {
        case .midnight: return "midnight"
        case .aurora: return "aurora"
        case .nebula: return "nebula"
        case .void: return "void"
        }
    }

    /// 保存主题选择到 UserDefaults
    func save() {
        UserDefaults.standard.set(identifier, forKey: Self.themeKey)
    }

    /// 从 UserDefaults 加载保存的主题
    /// - Returns: 保存的主题，如果没有保存则返回默认的 .midnight
    static func loadSaved() -> MystiqueTheme.Variant {
        let savedValue = UserDefaults.standard.string(forKey: themeKey)
        switch savedValue {
        case "midnight": return .midnight
        case "aurora": return .aurora
        case "nebula": return .nebula
        case "void": return .void
        default: return .midnight
        }
    }
}

// MARK: - 预览
#Preview("主题选择器 - 完整模式") {
    ThemeSelectorView()
        .mystiqueBackground()
        .environmentObject(MystiqueThemeManager())
}

#Preview("主题选择器 - 紧凑模式") {
    ThemeSelectorView(displayMode: .compact, showPreview: false)
        .background(DesignTokens.Color.basePalette.deepBackground)
        .environmentObject(MystiqueThemeManager())
}

#Preview("主题选择器 - 极简模式") {
    ThemeSelectorView(displayMode: .minimal, showPreview: false)
        .background(DesignTokens.Color.basePalette.deepBackground)
        .environmentObject(MystiqueThemeManager())
}
