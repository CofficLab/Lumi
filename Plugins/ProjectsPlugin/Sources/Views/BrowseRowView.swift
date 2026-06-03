import SwiftUI
import LumiUI

// MARK: - Browse Row View

public struct BrowseRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @Binding var isFileImporterPresented: Bool

    public var body: some View {
        AppListRow(isSelected: false, action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.appCallout)
                    .foregroundColor(theme.primary)

                Text(String(localized: "Select New Project", bundle: .module))
                    .font(.appBody)
                    .foregroundColor(theme.primary)

                Spacer()
            }
        }
    }
}
