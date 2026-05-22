import SwiftUI
import LumiUI

// MARK: - Browse Row View

struct BrowseRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @Binding var isFileImporterPresented: Bool

    var body: some View {
        AppListRow(isSelected: false, action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.appCallout)
                    .foregroundColor(theme.primary)

                Text(String(localized: "Select New Project", table: "RecentProjects"))
                    .font(.appBody)
                    .foregroundColor(theme.primary)

                Spacer()
            }
        }
    }
}
