import SwiftUI

/// 应用管理器空状态视图
struct AppManagerEmptyView: View {
    var searchText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("没有找到应用")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !searchText.isEmpty {
                Text("请尝试其他搜索关键词")
                    .foregroundStyle(.secondary)
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
    AppManagerLoadingView(message: "正在加载应用列表...")
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
