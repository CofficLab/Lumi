import SwiftUI

// MARK: - 玻璃输入框
///
/// 玻璃态输入框，优雅的文本输入体验。
///
struct GlassTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var placeholder: LocalizedStringKey = ""
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            if isSecure {
                secureFieldView
            } else {
                textFieldView
            }
        }
    }

    private var textFieldView: some View {
        TextField(placeholder, text: $text)
            .font(DesignTokens.Typography.body)
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            .padding(DesignTokens.Spacing.sm)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .cornerRadius(DesignTokens.Radius.sm)
    }

    private var secureFieldView: some View {
        SecureField("", text: $text)
            .font(DesignTokens.Typography.body)
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            .padding(DesignTokens.Spacing.sm)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .cornerRadius(DesignTokens.Radius.sm)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .fill(DesignTokens.Material.glass.opacity(isFocused ? 0.2 : 0.1))
    }

    @ViewBuilder private var fieldBorder: some View {
        let borderColor: SwiftUI.Color = isFocused
            ? DesignTokens.Color.semantic.primary
            : SwiftUI.Color.white.opacity(0.08)

        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
    }
}

// MARK: - 预览
#Preview("玻璃输入框") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GlassTextField(
            title: "用户名",
            text: .constant(""),
            placeholder: "请输入用户名"
        )
        .frame(width: 250)

        GlassTextField(
            title: "密码",
            text: .constant(""),
            placeholder: "请输入密码",
            isSecure: true
        )
        .frame(width: 250)
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
