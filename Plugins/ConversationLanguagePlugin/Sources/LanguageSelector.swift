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
