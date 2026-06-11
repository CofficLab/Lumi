import AgentToolKit
import LumiCoreKit
import SwiftUI

/// 语言切换按钮：每个对话保存独立语言偏好。
struct LanguageToggleButton: View {
    let languageContext: LanguagePreferenceContext

    @State private var isPopoverPresented = false
    @State private var selectedLanguage: LanguagePreference

    init(languageContext: LanguagePreferenceContext) {
        self.languageContext = languageContext
        self._selectedLanguage = State(initialValue: languageContext.restoredLanguage())
    }

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
        .accessibilityLabel(LumiPluginLocalization.string("Language Selector", bundle: .module))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            LanguagePopover(selectedLanguage: currentLanguage, onSelect: selectLanguage)
        }
        .onAppear(perform: syncLanguage)
        .onChange(of: languageContext.selectedConversationId) { _, _ in
            syncLanguage()
        }
        .onChange(of: languageContext.currentLanguage) { _, newValue in
            selectedLanguage = newValue
        }
    }

    private var currentLanguage: LanguagePreference {
        selectedLanguage
    }

    private func selectLanguage(_ language: LanguagePreference) {
        withAnimation {
            selectedLanguage = language
        }
        languageContext.save(language)
        isPopoverPresented = false
    }

    private func syncLanguage() {
        selectedLanguage = languageContext.restoredLanguage()
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
            return LumiPluginLocalization.string("Current Chinese Help", bundle: .module)
        case .english:
            return LumiPluginLocalization.string("Current English Help", bundle: .module)
        }
    }
}
