import SwiftUI

/// 加载中状态视图
///
/// 显示加载动画和提示文字。
struct CodeServerLoadingIndicatorView: View {
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(isRunning ? "正在启动 code-server…" : "正在查找 code-server…")
                .foregroundStyle(.secondary)
        }
    }
}
