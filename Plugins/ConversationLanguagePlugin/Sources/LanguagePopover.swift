import SwiftUI

struct LanguagePopover: View {
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
