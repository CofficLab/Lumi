import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatLanguagePicker: View {
    @LumiTheme private var theme

    let selectedLanguage: LumiConversationLanguage
    let onSelect: (LumiConversationLanguage) -> Void
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedLanguage.iconName)
                    .font(.system(size: 13, weight: .medium))
                Text(selectedLanguage.shortCode)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(selectedLanguage.displayName)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ChatLanguagePopover(selectedLanguage: selectedLanguage) { language in
                onSelect(language)
                isPopoverPresented = false
            }
        }
    }
}

private struct ChatLanguagePopover: View {
    @LumiTheme private var theme

    let selectedLanguage: LumiConversationLanguage
    let onSelect: (LumiConversationLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("语言")
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            ForEach(LumiConversationLanguage.allCases) { language in
                Button {
                    onSelect(language)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: language.iconName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(language == selectedLanguage ? .blue : theme.textSecondary)
                            .frame(width: 18)

                        Text(language.displayName)
                            .font(.appCaption)
                            .foregroundColor(theme.textPrimary)

                        Spacer(minLength: 8)

                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(language == selectedLanguage ? Color.blue.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 180)
    }
}
