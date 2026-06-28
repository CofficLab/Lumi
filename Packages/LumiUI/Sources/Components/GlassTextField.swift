import AppKit
import SwiftUI

public struct GlassTextField: View {
    @LumiTheme private var theme

    let title: Text
    @Binding var text: String
    let placeholder: Text
    var isSecure: Bool
    var allowsReveal: Bool
    var allowsCopy: Bool

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false
    @State private var didCopy = false

    public init(
        title: LocalizedStringKey,
        text: Binding<String>,
        placeholder: LocalizedStringKey = "",
        isSecure: Bool = false,
        allowsReveal: Bool = false,
        allowsCopy: Bool = false
    ) {
        self.title = Text(title)
        self._text = text
        self.placeholder = Text(placeholder)
        self.isSecure = isSecure
        self.allowsReveal = allowsReveal
        self.allowsCopy = allowsCopy
    }

    public init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        isSecure: Bool = false,
        allowsReveal: Bool = false,
        allowsCopy: Bool = false
    ) {
        self.title = Text(title)
        self._text = text
        self.placeholder = Text(placeholder)
        self.isSecure = isSecure
        self.allowsReveal = allowsReveal
        self.allowsCopy = allowsCopy
    }

    init(
        title: Text,
        text: Binding<String>,
        placeholder: Text,
        isSecure: Bool = false,
        allowsReveal: Bool = false,
        allowsCopy: Bool = false
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.allowsReveal = allowsReveal
        self.allowsCopy = allowsCopy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            title
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(theme.textTertiary)

            inputContainer
        }
        .onChange(of: isSecure) { _, secured in
            if !secured {
                isRevealed = false
            }
        }
    }

    @ViewBuilder
    private var inputContainer: some View {
        if isSecure, allowsReveal || allowsCopy {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Group {
                    if allowsReveal, isRevealed {
                        textFieldView
                    } else {
                        secureFieldView
                    }
                }

                if allowsReveal {
                    revealButton
                }
                if allowsCopy {
                    copyButton
                }
            }
        } else if isSecure {
            secureFieldView
        } else {
            textFieldView
        }
    }

    private var revealButton: some View {
        accessoryButton(
            systemImage: isRevealed ? "eye.slash" : "eye",
            help: isRevealed ? "隐藏 API Key" : "显示 API Key"
        ) {
            isRevealed.toggle()
        }
    }

    private var copyButton: some View {
        accessoryButton(
            systemImage: didCopy ? "checkmark" : "doc.on.doc",
            help: didCopy ? String(localized: "Copied", bundle: .module) : String(localized: "Copy API Key", bundle: .module),
            isEnabled: !text.isEmpty
        ) {
            guard !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            didCopy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                didCopy = false
            }
        }
    }

    private func accessoryButton(
        systemImage: String,
        help: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.body)
                .foregroundColor(isEnabled ? theme.textSecondary : theme.textTertiary.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(fieldBackground)
                .overlay(fieldBorder)
                .cornerRadius(DesignTokens.Radius.sm)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
    }

    private var textFieldView: some View {
        TextField("", text: $text, prompt: placeholder)
            .font(DesignTokens.Typography.body)
            .foregroundColor(theme.textPrimary)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .cornerRadius(DesignTokens.Radius.sm)
    }

    private var secureFieldView: some View {
        SecureField("", text: $text, prompt: placeholder)
            .font(DesignTokens.Typography.body)
            .foregroundColor(theme.textPrimary)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
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
