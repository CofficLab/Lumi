import SwiftUI

/// 请求日志状态栏视图按钮
///
/// 在状态栏显示一个图标，点击后弹出 Popover 展示请求日志数据库原始数据。
struct RequestLogStatusBarView: View {
    @StateObject private var viewModel = RequestLogBrowserViewModel()
    @EnvironmentObject private var themeVM: AppThemeVM
    @State private var isPresented = false

    private let iconSize: CGFloat = 10
    private let iconButtonSize: CGFloat = 22

    var body: some View {
        let theme = themeVM.activeAppTheme

        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: iconSize))
                .foregroundColor(theme.workspaceSecondaryTextColor())
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help(String(localized: "Request Log", table: "RequestLog"))
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            RequestLogDetailView(viewModel: viewModel)
                .frame(width: 980, height: 560)
        }
    }
}

#Preview("Request Log Status Bar") {
    RequestLogStatusBarView()
        .padding()
        .inRootView()
}
