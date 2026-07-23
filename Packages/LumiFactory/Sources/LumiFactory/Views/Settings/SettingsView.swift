import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

struct SettingsView: View {
    @LumiTheme private var theme

    /// 观察 kernel 以便 `kernel.settings?.allSettingsTabItems` 在插件注册/
    /// 注销时驱动 UI 重渲染(LumiKernelContainer 转发服务的 objectWillChange)。
    @ObservedObject var kernel: LumiKernel

    @State private var selectedTab: SettingsTabID = .builtin(.general)

    var body: some View {
        AppSettingsSidebarShell { sidebar } detail: {
            AppSettingsDetailPane { detail }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(theme.background)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSidebarHeaderView(kernel: kernel)

                AppSettingsDivider()

                VStack(spacing: 6) {
                    ForEach(descriptors) { descriptor in
                        AppSettingsSidebarItem(
                            title: descriptor.title,
                            systemImage: descriptor.systemImage,
                            isSelected: selectedTab == descriptor.id
                        ) {
                            selectedTab = descriptor.id
                        }
                    }
                }

                Spacer()
            }
        }
    }

    /// 把内置 4 个标签和插件贡献的 `SettingsTabItem` 平铺合并。
    private var descriptors: [SettingsTabDescriptor] {
        var items: [SettingsTabDescriptor] = SettingsTab.allCases.map {
            SettingsTabDescriptor(
                id: .builtin($0),
                title: $0.title,
                systemImage: $0.systemImage
            )
        }
        for item in kernel.settings?.allSettingsTabItems ?? [] {
            items.append(SettingsTabDescriptor(
                id: .plugin(item.id),
                title: item.title,
                systemImage: item.systemImage
            ))
        }
        return items
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedTab {
        case .builtin(.general):
            GeneralSettingsPage()
        case .builtin(.appearance):
            AppearanceSettingsPage(kernel: kernel)
        case .builtin(.plugins):
            PluginSettingsPage(kernel: kernel)
        case .builtin(.about):
            AboutPage()
        case .plugin(let id):
            pluginTabDetail(id: id)
        }
    }

    @ViewBuilder
    private func pluginTabDetail(id: String) -> some View {
        if let item = kernel.settings?.allSettingsTabItems.first(where: { $0.id == id }) {
            item.makeContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AppEmptyState(
                icon: "questionmark.folder",
                title: LumiLocalization.string("Settings tab unavailable", bundle: .module),
                description: LumiLocalization.string("This plugin is no longer providing this tab.", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
