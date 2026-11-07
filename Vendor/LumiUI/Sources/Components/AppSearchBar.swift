import SwiftUI

public struct AppSearchBar: View {
    @LumiTheme private var theme

    @Binding var text: String
    let placeholder: LocalizedStringKey
    let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, placeholder: LocalizedStringKey) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = nil
    }

    public init(text: Binding<String>, placeholder: LocalizedStringKey, onSubmit: @escaping () -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        #if os(iOS) || os(visionOS)
        iosBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS

    private var macBody: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppUI.Typography.caption1)
                .foregroundColor(theme.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
        .background(background)
        .cornerRadius(AppUI.Radius.sm)
    }

    // MARK: - iOS

    /// iOS 系统搜索框外观：三级填充底色、10pt 圆角、17pt 输入文字。
    private var iosBody: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.lumiSecondaryLabel)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.lumiPrimaryLabel)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.lumiSecondaryLabel)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.lumiTertiaryFill)
        }
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: AppUI.Radius.sm)
            .fill(AppUI.Material.glass)
            .appInputSurface(cornerRadius: AppUI.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                    .stroke(isFocused ? theme.primary.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            AppSearchBar(text: $text, placeholder: "搜索…")
                .padding(.horizontal)
        }
    }
    return PreviewWrapper()
        .frame(width: 300)
        .padding()
        .background(Color.gray.opacity(0.15))
}
