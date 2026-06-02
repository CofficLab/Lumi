import SwiftUI

public struct GlassTextField: View {
    @LumiTheme private var theme

    let title: Text
    @Binding var text: String
    let placeholder: Text
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool

    public init(
        title: LocalizedStringKey,
        text: Binding<String>,
        placeholder: LocalizedStringKey = "",
        isSecure: Bool = false
    ) {
        self.title = Text(title)
        self._text = text
        self.placeholder = Text(placeholder)
        self.isSecure = isSecure
    }

    public init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        isSecure: Bool = false
    ) {
        self.title = Text(title)
        self._text = text
        self.placeholder = Text(placeholder)
        self.isSecure = isSecure
    }

    init(title: Text, text: Binding<String>, placeholder: Text, isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            title
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(theme.textTertiary)

            if isSecure {
                secureFieldView
            } else {
                textFieldView
            }
        }
    }

    private var textFieldView: some View {
        TextField("", text: $text, prompt: placeholder)
            .font(DesignTokens.Typography.body)
            .foregroundColor(theme.textPrimary)
            .padding(DesignTokens.Spacing.sm)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .cornerRadius(DesignTokens.Radius.sm)
    }

    private var secureFieldView: some View {
        SecureField("", text: $text, prompt: placeholder)
            .font(DesignTokens.Typography.body)
            .foregroundColor(theme.textPrimary)
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
            ? theme.primary
            : SwiftUI.Color.white.opacity(0.08)

        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            VStack(spacing: 16) {
                GlassTextField(title: "Username", text: $text, placeholder: "Enter name")
                GlassTextField(title: "Password", text: $text, isSecure: true)
            }
            .padding()
            .frame(width: 300)
            .background(Color.gray.opacity(0.15))
        }
    }
    return PreviewWrapper()
}
