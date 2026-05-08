import SwiftUI

/// 编辑器加载状态视图。
///
/// 当文件内容、会话或相关资源仍在准备阶段时显示，用于给编辑区域提供简洁
/// 的加载反馈。
struct EditorLoadingStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text(String(localized: "Loading...", table: "LumiEditor"))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "98989E"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
