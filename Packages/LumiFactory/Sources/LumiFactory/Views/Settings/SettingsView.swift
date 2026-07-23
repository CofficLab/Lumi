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

    /// 设置界面渲染所必需的内核服务。任一缺失则整屏显示错误界面,
    /// 而不是用 `?? []` 静默降级成残缺的 UI。
    private var missingServices: [String] {
        var missing: [String] = []
        if kernel.settings == nil { missing.append("Settings") }
        if kernel.theme == nil { missing.append("Theme") }
        return missing
    }

    var body: some View {
        if !missingServices.isEmpty {
            SettingsUnavailableView(missingServices: missingServices)
        } else {
            settingsBody
        }
    }

    private var settingsBody: some View {
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

    /// 把内置标签和插件贡献的 `SettingsTabItem` 平铺合并。
    ///
    /// 此处能安全强解包 `kernel.settings`,是因为 `body` 已在
    /// `missingServices` 非空时改显示 `SettingsUnavailableView`,不会进入此分支。
    private var descriptors: [SettingsTabDescriptor] {
        var items: [SettingsTabDescriptor] = SettingsTab.allCases.map {
            SettingsTabDescriptor(
                id: .builtin($0),
                title: $0.title,
                systemImage: $0.systemImage
            )
        }
        guard let settings = kernel.settings else { return items }
        for item in settings.allSettingsTabItems {
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
        case .builtin(.about):
            AboutPage()
        case .plugin(let id):
            pluginTabDetail(id: id)
        }
    }

    @ViewBuilder
    private func pluginTabDetail(id: String) -> some View {
        // settings 已在 body 中校验非 nil;此处对单个 tab 仍保留解包兜底,
        // 避免运行期某个 tab 被插件取消贡献后强解包崩溃。
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
