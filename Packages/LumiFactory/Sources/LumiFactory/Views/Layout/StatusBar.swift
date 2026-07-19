import LumiKernel
import LumiUI
import SwiftUI

/// 状态栏视图
///
/// 显示所有插件注册的状态栏项，按位置分为左侧、中间、右侧三个区域。
struct StatusBar: View {
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        let leadingItems = kernel.statusBarItems(placement: .leading)
        let centerItems = kernel.statusBarItems(placement: .center)
        let trailingItems = kernel.statusBarItems(placement: .trailing)

        HStack(spacing: 14) {
            ForEach(leadingItems) { item in
                StatusBarPluginButton(item: item)
            }

            Spacer()

            ForEach(centerItems) { item in
                StatusBarPluginButton(item: item)
            }

            Spacer()

            ForEach(trailingItems) { item in
                StatusBarPluginButton(item: item)
            }
        }
        .font(.caption)
        .foregroundStyle(statusBarForegroundColor)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .appSurface(style: .custom(statusBarBackgroundColor), cornerRadius: 0)
        .overlay(alignment: .top) {
            AppDivider()
        }
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
