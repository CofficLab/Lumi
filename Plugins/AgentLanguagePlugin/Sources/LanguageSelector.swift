import AgentToolKit
import LumiCoreKit
import SwiftUI

/// 语言切换按钮：每个对话保存独立语言偏好。
struct LanguageToggleButton: View {
    @EnvironmentObject private var projectVM: PluginProjectContext
    @EnvironmentObject private var conversationVM: WindowConversationVM

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: currentLanguage.iconName)
                    .font(.system(size: 13))
                Text(currentLanguage.shortDisplayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(String(localized: "Language Selector", bundle: .module))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            LanguagePopover(selectedLanguage: currentLanguage, onSelect: selectLanguage)
        }
        .onAppear(perform: restoreConversationPreference)
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            restoreConversationPreference()
        }
    }

    private var currentLanguage: LanguagePreference {
        projectVM.languagePreference
    }

    private func selectLanguage(_ language: LanguagePreference) {
        withAnimation {
            projectVM.setLanguagePreference(language)
        }
        conversationVM.saveLanguagePreference(language)
        isPopoverPresented = false
    }

    private func restoreConversationPreference() {
        guard let preference = conversationVM.getLanguagePreference() else { return }
        projectVM.setLanguagePreference(preference)
    }

    private var foregroundColor: Color {
        switch currentLanguage {
        case .chinese:
            return .blue
        case .english:
            return .purple
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    private var helpText: String {
        switch currentLanguage {
        case .chinese:
            return String(localized: "Current Chinese Help", bundle: .module)
        case .english:
            return String(localized: "Current English Help", bundle: .module)
        }
    }
}

private struct LanguagePopover: View {
    let selectedLanguage: LanguagePreference
    let onSelect: (LanguagePreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Response Language", bundle: .module))
                .font(.system(size: 13, weight: .semibold))

            ForEach(LanguagePreference.allCases) { language in
                Button {
                    onSelect(language)
                } label: {
                    LanguageRow(language: language, isSelected: language == selectedLanguage)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 220)
    }
}

private struct LanguageRow: View {
    let language: LanguagePreference
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: language.iconName)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(isSelected ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(language.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(language.descriptionText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

extension LanguagePreference {
    var shortDisplayName: String {
        switch self {
        case .chinese: return "中"
        case .english: return "EN"
        }
    }

    var iconName: String {
        switch self {
        case .chinese: return "character.book.closed"
        case .english: return "textformat.abc"
        }
    }

    var descriptionText: String {
        switch self {
        case .chinese:
            return String(localized: "Chinese Description", bundle: .module)
        case .english:
            return String(localized: "English Description", bundle: .module)
        }
    }
}
