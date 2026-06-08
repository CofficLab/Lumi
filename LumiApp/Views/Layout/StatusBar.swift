import LumiCoreKit
import LumiUI
import SwiftUI

struct StatusBar: View {
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    let state: LayoutState
    @ObservedObject var pluginService: PluginService
    let activeID: String
    let activeTitle: String
    let lumiUIService: LumiUIService

    var body: some View {
        let context = LumiPluginContext(
            activeSectionID: activeID,
            activeSectionTitle: activeTitle,
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiThemeServicing.self, lumiUIService)
            }
        )
        let items = pluginService.statusBarItems(context: context)
        let leadingItems = items.filter { $0.placement == .leading }
        let centerItems = items.filter { $0.placement == .center }
        let trailingItems = items.filter { $0.placement == .trailing }

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
            Rectangle()
                .fill(statusBarDividerColor)
                .frame(height: 1)
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

    private var statusBarDividerColor: Color {
        chromeTheme.statusBarDividerColor()
    }
}

private struct StatusBarPluginButton: View {
    let item: LumiStatusBarItem
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
