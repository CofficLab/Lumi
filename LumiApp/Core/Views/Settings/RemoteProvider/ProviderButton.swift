import SwiftUI

/// 供应商选择按钮组件
struct ProviderButton: View {
    let provider: LLMProviderInfo
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(provider.displayName)
                    .font(DesignTokens.Typography.caption1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(provider.displayName)
        .accessibilityHint("双击切换 LLM 供应商")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected { return DesignTokens.Color.semantic.primary }
        if isHovered { return Color.white.opacity(0.12) }
        return Color.white.opacity(0.05)
    }

    private var foregroundColor: Color {
        if isSelected { return .white }
        return DesignTokens.Color.semantic.textSecondary
    }
}
