import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatModelSelectorModelRow: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    let model: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primary)
                    }

                    Spacer()
                }

                HStack(spacing: 6) {
                    AppTag(provider.displayName)
                    AppTag(provider.id, systemImage: "cloud")
                    Spacer()
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
    }
}
