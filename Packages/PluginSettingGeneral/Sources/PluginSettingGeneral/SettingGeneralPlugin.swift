import KernelCore
import LumiUI
import ProviderCommand
import ProviderDocsView
import ProviderSettingView
import SwiftUI

/// 设置 - 通用 插件
///
/// 在设置视图中注册「通用」入口，包含 `AppSettingsContentScaffold`
/// 包裹的四个分组卡片（新手引导 / Lumi / 网站 / 更新），每行均为
/// `AppSettingRow`（图标 + 标题 + 描述 + 右侧 `AppButton`）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `SettingViewProviding`
/// 与 `DocsViewProviding`，用 `addEntries(_:)`（追加语义）注册入口，
/// 不覆盖其他插件贡献的入口。
@MainActor
public final class SettingGeneralPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.setting-general"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.setting-general",
        name: "通用设置",
        description: "在设置视图中注册「通用」入口，包含新手引导、应用信息、网站与更新。",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 版本字符串提供器；默认读取 App bundle 版本，可注入以便测试。
    private let versionProvider: @MainActor () -> String?

    public init(versionProvider: @escaping @MainActor () -> String? = { AppVersion.current }) {
        self.versionProvider = versionProvider
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any CommandProviding).self)?.registerCommandGroup(
            CommandMenuGroup(
                id: "\(id).commands",
                name: "Settings",
                items: [
                    CommandItem(
                        id: "\(id).openSettings",
                        title: LumiPluginLocalization.string("Settings...", bundle: .module),
                        shortcut: ",",
                        modifiers: .command
                    ) {
                        NotificationCenter.default.post(
                            name: Notification.Name("lumi.openSettings"),
                            object: nil
                        )
                    },
                ],
                placement: .appMenu
            )
        )

        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }

        // 捕获 docs provider 引用，供详情视图读取。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)

        let entry = SettingEntryItem(
            id: "general",
            title: "通用",
            systemImage: "gearshape",
            order: 1
        ) { [versionProvider, docsProvider] in
            GeneralSettingsDetailView(
                version: versionProvider(),
                docsProvider: docsProvider
            )
        }

        settings.addEntries([entry])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any CommandProviding).self)?
            .unregisterCommandGroup(id: "\(id).commands")
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["general"])
    }
}
