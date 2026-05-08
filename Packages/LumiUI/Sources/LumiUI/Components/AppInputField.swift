import SwiftUI

public struct AppInputField: View {
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(DesignTokens.Material.glass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
