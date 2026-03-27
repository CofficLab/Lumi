import SwiftUI

// MARK: - 玻璃选择卡片
///
/// 可选择的卡片，带有选中状态指示器
/// 用于单选列表、主题选择等场景
///
struct GlassSelectionCard<Content: View>: View {
    // MARK: - 配置
    var isSelected: Bool = false
    var showCheckmark: Bool = true
    var checkmarkColor: Color? = nil
    var selectedBackgroundColor: Color? = nil
    var selectedBorderColor: Color? = nil

    @ViewBuilder var content: Content

    // MARK: - 状态
    @State private var isHovering = false

    // MARK: - 主体
    var body: some View {
        Button(action: {}) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 内容
                content

                Spacer()

                // 选中指示器
                if showCheckmark && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(checkmarkColor ?? selectedColor)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(cardBackground)
            .overlay(cardBorder)
            .cornerRadius(DesignTokens.Radius.md)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DesignAnimations.Preset.responsive, value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: - 卡片背景
    @ViewBuilder private var cardBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(selectedBackgroundColor ?? selectedColor.opacity(0.15))
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.Material.glass.opacity(0.1))
        }
    }

    // MARK: - 卡片边框
    @ViewBuilder private var cardBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(selectedBorderColor ?? selectedColor, lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(SwiftUI.Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - 计算属性
    private var selectedColor: Color {
        checkmarkColor ?? DesignTokens.Color.semantic.primary
    }
}

// MARK: - 预定义样式
extension GlassSelectionCard {
    /// 主题选择样式
    func themeStyle(_ color: Color) -> GlassSelectionCard {
        var copy = self
        copy.checkmarkColor = color
        copy.selectedBackgroundColor = color.opacity(0.15)
        copy.selectedBorderColor = color
        return copy
    }
}

// MARK: - 预览
#Preview("选择卡片") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        GlassSelectionCard(isSelected: true) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "moon.fill")
                    .foregroundColor(.purple)
                VStack(alignment: .leading) {
                    Text("午夜主题")
                        .font(DesignTokens.Typography.body)
                    Text("深邃神秘的午夜氛围")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }
        }

        GlassSelectionCard(isSelected: false) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text("阳光主题")
                        .font(DesignTokens.Typography.body)
                    Text("温暖明亮的阳光")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
