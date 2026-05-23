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

            Text(String(localized: "No applications found", table: "AppManager"))
                .font(.appSectionTitle)
                .foregroundColor(theme.textSecondary)

            if !searchText.isEmpty {
                Text(String(localized: "Try other search keywords", table: "AppManager"))
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("AppManagerLoadingView") {
    AppManagerLoadingView()
        .frame(width: 400, height: 300)
}

#Preview("AppManagerLoadingView - Custom Message") {
    AppManagerLoadingView(message: "Loading application list...")
        .frame(width: 400, height: 300)
}

#Preview("AppManagerEmptyView - No Search") {
    AppManagerEmptyView(searchText: "")
        .frame(width: 400, height: 300)
}

#Preview("AppManagerEmptyView - With Search") {
    AppManagerEmptyView(searchText: "test")
        .frame(width: 400, height: 300)
}
