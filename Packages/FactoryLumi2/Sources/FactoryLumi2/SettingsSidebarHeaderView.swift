import LumiUI
import ProviderLogo
import SwiftUI

/// 设置窗口侧边栏顶部的 Header：应用 Logo（64×64）+ 名称 + 版本。
///
/// 复刻 LumiApp 设置界面的体验：优先展示最高优先级插件贡献的 Logo
/// （`about` 场景，彩色/动画），未注册 Logo 时回退到主题色 `app.fill` 图标。
struct SettingsSidebarHeaderView: View {
    /// 从共享内核解析的 Logo 服务；`nil` 时仅显示回退图标。
    let logo: (any LogoProviding)?

    @LumiTheme private var theme

    private let appInfo = AppBundleInfo()

    var body: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 22)

            Group {
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
            .frame(width: 64, height: 64)

            Text(appInfo.name)
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)

            VStack(spacing: 2) {
                Text("v\(appInfo.version)")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                Text("Build \(appInfo.build)")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Spacer().frame(height: 8)
        }
    }
}

#Preview("Settings Sidebar Header") {
    SettingsSidebarHeaderView(logo: nil)
        .frame(width: 220)
        .padding()
}
