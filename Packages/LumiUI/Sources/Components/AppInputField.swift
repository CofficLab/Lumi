import SwiftUI

public struct AppInputField: View {
    @LumiTheme private var theme

    public enum FieldType {
        case plain
        case secure
    }

    let placeholder: LocalizedStringKey
    @Binding var text: String
    let fieldType: FieldType

    public init(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        fieldType: FieldType = .plain
    ) {
        self.placeholder = placeholder
        self._text = text
        self.fieldType = fieldType
    }

    public var body: some View {
        Group {
            switch fieldType {
            case .plain:
                TextField(placeholder, text: $text)
            case .secure:
                SecureField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(DesignTokens.Typography.body)
        .foregroundColor(theme.textPrimary)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(theme.appListRowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(theme.appSubtleBorder, lineWidth: 1)
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            VStack(spacing: 16) {
                AppInputField("placeholder.plain", text: $text, fieldType: .plain)
                AppInputField("placeholder.secure", text: $text, fieldType: .secure)
            }
            .padding()
            .frame(width: 300)
            .background(Color.gray.opacity(0.15))
        }
    }
    return PreviewWrapper()
}
