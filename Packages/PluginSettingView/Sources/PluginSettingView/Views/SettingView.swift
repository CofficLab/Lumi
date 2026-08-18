import Foundation
import SwiftUI
import ProviderLogo
import ProviderSettingView
import LumiUI

struct SettingView<Provider: SettingViewProviding & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @State private var selectedID: String?
    @LumiTheme private var theme

    /// 从共享内核解析的 Logo 服务；`nil` 时侧边栏 Header 仅显示回退图标。
    private let logo: (any LogoProviding)?
    private let appInfo = AppBundleInfo()

    init(provider: Provider, logo: (any LogoProviding)?) {
        self.provider = provider
        self.logo = logo
        _selectedID = State(initialValue: provider.selectedEntryID)
    }

    var body: some View {
        AppSettingsSidebarShell {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(theme.background)
        .appThemedAppearance()
        #if canImport(AppKit)
            .background {
                ThemeWindowAppearanceBridge()
            }
        #endif
            .ignoresSafeArea()
    }

    /// 左侧：顶部 Logo Header（应用 Logo + 名称 + 版本）+ 入口列表。
    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                HeaderView(logo: logo)

                AppSettingsDivider()

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(provider.entries) { entry in
                            AppSettingsSidebarItem(
                                title: entry.title,
                                systemImage: entry.systemImage,
                                isSelected: (selectedID ?? provider.selectedEntryID) == entry.id
                            ) {
                                selectedID = entry.id
                                provider.selectEntry(id: entry.id)
                            }
                        }
                    }
                    .padding(.leading)
                }

                Spacer()
            }
        }
    }

    /// 右侧：详情视图（氛围渐变背景），无选中时显示与旧版一致的空状态。
    private var detail: some View {
        AppSettingsDetailPane {
            Group {
                if let selected = provider.entries.first(where: { $0.id == selectedID ?? provider.selectedEntryID }) {
                    selected.makeDetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppEmptyState(
                        icon: "gearshape",
                        title: "Select a tab"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
