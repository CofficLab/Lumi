import SwiftUI
import MagicKit

/// 项目文件树空状态视图
struct ProjectTreeEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("暂无文件")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}
