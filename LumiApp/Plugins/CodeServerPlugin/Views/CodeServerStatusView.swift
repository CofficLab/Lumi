import SwiftUI

/// Code Server 加载 / 错误过渡视图
///
/// 根据当前状态展示加载中或错误提示。
struct CodeServerStatusView: View {
    let isRunning: Bool
    let errorMessage: String?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                CodeServerLoadingIndicatorView(isRunning: isRunning)
            } else if let error = errorMessage {
                CodeServerErrorView(errorMessage: error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
