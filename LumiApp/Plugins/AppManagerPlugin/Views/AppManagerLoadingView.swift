import SwiftUI
import LumiUI

/// 应用管理器加载状态视图
struct AppManagerLoadingView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var message: String = String(localized: "Scanning applications...", table: "AppManager")

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
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
