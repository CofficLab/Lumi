import LumiKernel
import LumiUI
import SwiftUI

/// 新版状态栏（最小实现）
///
/// 后续插件迁移后可恢复插件贡献的状态栏项。
struct StatusBar: View {
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        HStack(spacing: 14) {
            Text("Lumi")
                .font(.caption)

            Spacer()

            Text(kernel.allPlugins.count == 1
                 ? "1 plugin"
                 : "\(kernel.allPlugins.count) plugins")
                .font(.caption)
        }
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
