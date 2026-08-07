import LumiKernel
import LumiUI
import SwiftUI

/// 状态栏视图
///
/// 显示所有插件注册的状态栏项，按位置分为左侧、中间、右侧三个区域。
/// 如果工作区服务（WorkspaceProviding）不可用，显示错误提示。
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次初值，监听 `.workspaceContributionsDidChange`
/// 重新拉取三个位置的 status bar items。
struct StatusBar: View {
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    let kernel: LumiKernel

    @State private var statusBarResult: Result<StatusBarItems, Error>

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _statusBarResult = State(initialValue: Self.makeStatusBarResult(workspace: kernel.workspace))
    }

    var body: some View {
        VStack(spacing: 0) {
            switch statusBarResult {
            case .success(let items):
                statusBarContent(
                    leading: items.leading,
                    center: items.center,
                    trailing: items.trailing
                )
            case .failure(let error):
                StatusBarErrorView(message: error.localizedDescription)
            }
        }
        .overlay(alignment: .top) {
            AppDivider()
        }
        .onWorkspaceContributionsDidChange {
            statusBarResult = Self.makeStatusBarResult(workspace: kernel.workspace)
        }
    }

    private static func makeStatusBarResult(workspace: (any WorkspaceProviding)?) -> Result<StatusBarItems, Error> {
        guard let workspace else {
            return .failure(LumiKernelError.serviceNotAvailable(service: "Workspace"))
        }
        let leading = workspace.statusBarItems(placement: .leading)
        let center = workspace.statusBarItems(placement: .center)
        let trailing = workspace.statusBarItems(placement: .trailing)
        return .success(StatusBarItems(leading: leading, center: center, trailing: trailing))
    }

    private func statusBarContent(leading: [StatusBarItem], center: [StatusBarItem], trailing: [StatusBarItem]) -> some View {
        HStack(spacing: 14) {
            ForEach(leading) { item in
                StatusBarPluginButton(item: item)
            }

            Spacer()

            ForEach(center) { item in
                StatusBarPluginButton(item: item)
            }

            Spacer()

            ForEach(trailing) { item in
                StatusBarPluginButton(item: item)
            }
        }
        .font(.caption)
        .foregroundStyle(statusBarForegroundColor)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .appSurface(style: .custom(statusBarBackgroundColor), cornerRadius: 0)
    }

    private var chromeTheme: any LumiAppChromeTheme {
        themeRegistry.chromeTheme
    }

    private var statusBarBackgroundColor: Color {
        chromeTheme.statusBarBackgroundColor()
    }

    private var statusBarForegroundColor: Color {
        chromeTheme.statusBarForegroundColor()
    }
}

// MARK: - Status Bar Items Container

private struct StatusBarItems {
    let leading: [StatusBarItem]
    let center: [StatusBarItem]
    let trailing: [StatusBarItem]
}

// MARK: - Status Bar Plugin Button

private struct StatusBarPluginButton: View {
    let item: StatusBarItem
    @LumiTheme private var theme
    @State private var isPresented = false

    var body: some View {
        if let makeStatusBarView = item.makeStatusBarView {
            makeStatusBarView()
                .help(item.title)
        } else {
            AppIconButton(
                systemImage: item.systemImage,
                label: item.title,
                tint: theme.statusBarItemForeground,
                isActive: isPresented
            ) {
                NSApp.keyWindow?.makeFirstResponder(nil)
                NSApp.mainWindow?.makeFirstResponder(nil)
                isPresented.toggle()
            }
            .help(item.title)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                item.makePopoverView()
            }
        }
    }
}
