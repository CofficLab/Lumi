import Foundation
import SwiftUI
import ProviderLogo
import ProviderSettingView
import LumiUI

struct SettingView<Provider: SettingViewProviding & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @LumiTheme private var theme

    /// 从共享内核解析的 Logo 服务；`nil` 时侧边栏 Header 仅显示回退图标。
    private let logo: (any LogoProviding)?
    private let appInfo = AppBundleInfo()

    init(provider: Provider, logo: (any LogoProviding)?) {
        self.provider = provider
        self.logo = logo
    }

    var body: some View {
        AppSettingsSidebarShell {
            sidebar
        } detail: {
            detail
        }
        // The appearance page contains a second split view (theme list + preview)
        // whose usable width is larger than the legacy 720pt settings window.
        // Keep the host window from laying out that content outside both edges.
        .frame(minWidth: 960, minHeight: 520)
        .background(theme.background)
        .appThemedAppearance()
        .onAppear(perform: selectFirstEntryIfNeeded)
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
                                isSelected: provider.selectedEntryID == entry.id
                            ) {
                                provider.selectEntry(id: entry.id)
                            }
                        }
                    }
                    .padding(.leading)
                    .padding(.trailing)
                }

                Spacer()
            }
        }
    }

    /// 右侧：详情视图（氛围渐变背景），无选中时显示空状态。
    private var detail: some View {
        AppSettingsDetailPane {
            Group {
                if let selected = provider.entries.first(where: { $0.id == provider.selectedEntryID }) {
                    selected.makeDetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppEmptyState(
                        icon: "gearshape",
                        title: LumiPluginLocalization.string("Select a tab", bundle: .module)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func selectFirstEntryIfNeeded() {
        guard provider.selectedEntryID == nil,
              let firstEntry = provider.entries.first else { return }
        provider.selectEntry(id: firstEntry.id)
    }
}
