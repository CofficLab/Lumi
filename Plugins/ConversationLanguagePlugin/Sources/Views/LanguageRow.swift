import LumiCoreKit
import SwiftUI

struct LanguageRow: View {
    let language: LumiConversationLanguage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: language.toolbarIconName)
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
