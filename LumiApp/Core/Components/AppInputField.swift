import SwiftUI

/// 通用输入框组件：统一普通/安全输入的视觉风格。
struct AppInputField: View {
    enum FieldType {
        case plain
        case secure
    }

    let placeholder: LocalizedStringKey
    @Binding var text: String
    let fieldType: FieldType

    init(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        fieldType: FieldType = .plain
    ) {
        self.placeholder = placeholder
        self._text = text
        self.fieldType = fieldType
    }

    var body: some View {
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

#Preview {
    VStack(spacing: 12) {
        AppInputField("请输入内容", text: .constant(""))
        AppInputField("请输入 API Key", text: .constant(""), fieldType: .secure)
    }
    .padding()
    .inRootView()
}
