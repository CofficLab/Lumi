import LumiKernel
import LumiUI
import SwiftUI

/// 状态栏视图
///
/// 显示所有插件注册的状态栏项，按位置分为左侧、中间、右侧三个区域。
/// 如果 StatusBarProviding 服务不可用，显示错误提示。
struct StatusBar: View {
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @ObservedObject var kernel: LumiKernel

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
    }

    private var statusBarResult: Result<StatusBarItems, Error> {
        do {
            guard let statusBarService = kernel.statusBar else {
                throw LumiKernelError.serviceNotAvailable(service: "StatusBar")
            }
            let leading = try statusBarService.statusBarItems(placement: .leading)
            let center = try statusBarService.statusBarItems(placement: .center)
            let trailing = try statusBarService.statusBarItems(placement: .trailing)
            return .success(StatusBarItems(leading: leading, center: center, trailing: trailing))
        } catch {
            return .failure(error)
        }
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
    @State private var isPresented = false

    var body: some View {
        if let makeStatusBarView = item.makeStatusBarView {
            makeStatusBarView()
                .help(item.title)
        } else {
            AppIconButton(
                systemImage: item.systemImage,
                label: item.title,
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
