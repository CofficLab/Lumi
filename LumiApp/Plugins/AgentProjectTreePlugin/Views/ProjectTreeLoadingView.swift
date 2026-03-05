import SwiftUI
import MagicKit

/// 项目文件树加载状态视图
struct ProjectTreeLoadingView: View {
    var body: some View {
        HStack(spacing: 4) {
            ProgressView()
                .frame(width: 10, height: 10)
            Text("加载中...")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }
}
