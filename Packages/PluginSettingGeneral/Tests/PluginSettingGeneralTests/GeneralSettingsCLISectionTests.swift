import KernelCore
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginSettingGeneral

/// 通用设置页中「命令行工具」分区的接入验证。
@Suite("通用设置 · 命令行工具分区")
@MainActor
struct GeneralSettingsCLISectionTests {

    /// 渲染通用设置详情视图，确认不抛错。
    ///
    /// 该分区是纯 SwiftUI 结构，渲染成功即说明
    /// `CLIInstallDetailView` 与 `AppSettingSection` / `AppSettingRow` /
    /// `AppButton` 的组合是合法的。
    @Test("通用设置详情视图可渲染命令行工具分区")
    func generalSettingsRendersCLISection() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin(versionProvider: { "1.2.3 (45)" })
        try plugin.onBoot(kernel: kernel)

        let entry = try #require(settings.entries.first)
        let detail = entry.makeDetailView()
        #expect(type(of: detail) == AnyView.self)
    }

    @Test("命令行工具分区不要求内核 Provider 即可工作")
    func clisectionWorksWithoutOptionalProviders() throws {
        // CLI 安装只依赖文件系统与 App 自身，不依赖 Docs / Diagnostics /
        // Storage / Uninstall 等 Provider；缺少它们时设置页仍应能注册入口。
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.count == 1)
        #expect(settings.entries[0].id == "general")
    }
}
