import SwiftUI
import LumiUI

/// 请求日志状态栏视图按钮
///
/// 在状态栏显示一个图标，点击后弹出 Popover 展示请求日志数据库原始数据。
public struct RequestLogStatusBarView: View {
    @StateObject private var viewModel = RequestLogBrowserViewModel()

    public var body: some View {
        StatusBarHoverContainer(
            detailView: RequestLogDetailView(viewModel: viewModel),
            popoverWidth: 980,
            id: "agent-request-log"
        ) {
            HStack(spacing: 6) {
                Image(systemName: RequestLogPlugin.iconName)
                    .font(.appMicroEmphasized)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

#Preview("Request Log Status Bar") {
    RequestLogStatusBarView()
        .padding()
        .inRootView()
}
