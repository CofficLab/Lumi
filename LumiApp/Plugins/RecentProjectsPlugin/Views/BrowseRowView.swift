import SwiftUI
import LumiUI

// MARK: - Browse Row View

struct BrowseRowView: View {
    @Binding var isFileImporterPresented: Bool

    var body: some View {
        AppListRow(isSelected: false, action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)

                Text(String(localized: "Select New Project", table: "RecentProjects"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.accentColor)

                Spacer()
            }
        }
    }
}
