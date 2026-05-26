import SwiftUI
import LumiUI

/// 应用管理器空状态视图
struct AppManagerEmptyView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var searchText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)

            Text(PluginAppManagerLocalization.string("No applications found"))
                .font(.appSectionTitle)
                .foregroundColor(theme.textSecondary)

            if !searchText.isEmpty {
                Text(PluginAppManagerLocalization.string("Try other search keywords"))
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
