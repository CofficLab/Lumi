import SwiftUI
import MagicKit

/// 项目文件树标题栏视图
/// 展示「文件树」标题和刷新按钮
struct ProjectTreeHeaderView: View {
    /// 刷新动作回调
    let onRefresh: () -> Void

    // MARK: - View

    var body: some View {
        HStack {
            Text("文件树")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("ProjectTreeHeaderView - Small") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .overlay {
            ProjectTreeHeaderView(onRefresh: {})
                .padding()
        }
        .frame(width: 800, height: 200)
}

#Preview("ProjectTreeHeaderView - Large") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .overlay {
            ProjectTreeHeaderView(onRefresh: {})
                .padding()
        }
        .frame(width: 1200, height: 400)
}

