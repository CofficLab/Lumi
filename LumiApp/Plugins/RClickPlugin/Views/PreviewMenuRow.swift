import LumiUI
import SwiftUI

struct PreviewMenuRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let item: RClickMenuItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.iconName)
                .font(.appCallout)
                .frame(width: 16)
                .foregroundColor(theme.textSecondary)

            Text(item.title)
                .font(.appCallout)
                .foregroundColor(theme.textPrimary)

            Spacer()

            if item.type == .newFile {
                Image(systemName: "chevron.right")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
