import LumiUI
import ProviderLogo
import SwiftUI

/// 设置窗口侧边栏顶部的 Header：应用 Logo（64×64）+ 名称 + 版本。
///
/// 复刻旧版 Lumi（`FactoryCore.SettingsSidebarHeaderView`）的视觉：
/// 使用 `AppSettingsSidebarHeader` 统一排版，顶部 Logo 由 `PluginSettingView`
/// 从共享内核解析的 `LogoProviding` 提供（`about` 场景，彩色/动画），
/// 未注册 Logo 时回退到主题色 `app.fill` 图标。
struct SettingsSidebarHeaderView: View {
    /// 从共享内核解析的 Logo 服务；`nil` 时仅显示回退图标。
    let logo: (any LogoProviding)?

    @LumiTheme private var theme

    private let appInfo = AppBundleInfo()

    var body: some View {
        AppSettingsSidebarHeader(
            name: appInfo.name,
            version: appInfo.version,
            build: appInfo.build,
            topSpacing: 22,
            bottomSpacing: 8
        ) {
            HStack {
                Spacer()
                logoView
                    .frame(width: 64, height: 64)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var logoView: some View {
        if let item = logo?.highestPriorityLogoItem {
            item.makeView(.about)
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
        }
    }
}

#Preview("Settings Sidebar Header") {
    SettingsSidebarHeaderView(logo: nil)
        .frame(width: 220)
        .padding()
}
