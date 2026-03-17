import SwiftUI

/// 应用管理器空状态视图
struct AppManagerEmptyView: View {
    var searchText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text(String(localized: "No applications found"))
                .font(.title3)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            if !searchText.isEmpty {
                Text(String(localized: "Try other search keywords"))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
