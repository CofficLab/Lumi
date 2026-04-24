import SwiftUI

/// 错误状态视图
///
/// 显示错误图标和错误信息。
struct CodeServerErrorView: View {
    let errorMessage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("无法连接 code-server")
                .font(.headline)
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
