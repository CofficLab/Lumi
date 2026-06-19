import LumiCoreKit
import SwiftUI

struct LanguagePopover: View {
    let selectedLanguage: LumiConversationLanguage
    let onSelect: (LumiConversationLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LumiPluginLocalization.string("Response Language", bundle: .module))
                .font(.system(size: 13, weight: .semibold))

            ForEach(LumiConversationLanguage.allCases) { language in
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
