import LumiKernel
import SwiftUI

struct LanguageRow: View {
    let language: LumiConversationLanguage
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: language.toolbarIconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(language.displayName)
                    .font(.system(size: 12, weight: .semibold))

                Text(language.descriptionText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
