import SwiftUI

/// 错误状态视图
///
/// 显示错误图标、错误信息和重试按钮。
struct CodeServerErrorView: View {
    let errorMessage: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(String(localized: "无法连接 code-server", table: "CodeServer"))
                .font(.headline)
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label(String(localized: "重试", table: "CodeServer"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}
