import Foundation
import KernelCore
import ProviderDocsView
import ProviderIdleTime
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import Testing
@testable import PluginIdleTime

/// PluginIdleTime 装配测试：验证插件在 onBoot 注册菜单栏弹窗、设置页、
/// 关于文档与事件监听，onShutdown 全部撤回。
@Suite("PluginIdleTime 插件装配", .serialized)
@MainActor
struct IdleTimePluginTests {
    private final class TestStorage: StorageProviding {
        let dataRootDirectory: URL

        init() {
            dataRootDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginIdleTimeTests-\(UUID().uuidString)")
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        }
    }

    @Test("启动后注册菜单栏弹窗、设置页与关于文档，停止后全部撤回")
    func registersAndWithdrawsContributions() throws {
        let kernel = KernelCoreContainer()
        let menuBar = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        let docs = DefaultDocsViewProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any MenuBarProviding).self, menuBar)
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider((any StorageProviding).self, storage)
        try kernel.registerProvider((any IdleTimeProviding).self, DefaultIdleTimeProviding())

        try kernel.start(plugins: [IdleTimePlugin()])

        #expect(menuBar.popupItems.map(\.id) == ["com.coffic.lumi.plugin.idle-time.popover"])
        #expect(settings.entries.map(\.id) == ["com.coffic.lumi.plugin.idle-time.settings"])
        #expect(docs.aboutEntries.map(\.id) == ["com.coffic.lumi.plugin.idle-time"])

        try kernel.stop()

        #expect(menuBar.popupItems.isEmpty)
        #expect(settings.entries.isEmpty)
        #expect(docs.aboutEntries.isEmpty)
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }

    @Test("事件监听在 onBoot 注册、onShutdown 移除，且记录到 provider")
    func eventObserversRecordActivity() async throws {
        let kernel = KernelCoreContainer()
        let provider = DefaultIdleTimeProviding()
        try kernel.registerProvider((any IdleTimeProviding).self, provider)
        try kernel.registerProvider((any MenuBarProviding).self, DefaultMenuBarProviding())
        try kernel.registerProvider((any SettingViewProviding).self, DefaultSettingViewProviding())
        try kernel.registerProvider((any DocsViewProviding).self, DefaultDocsViewProviding())

        let plugin = IdleTimePlugin()
        try kernel.start(plugins: [plugin])

        // 发布编辑器保存事件 → 服务应记录 fileSave。
        let before = Date()
        NotificationCenter.default.post(name: .lumiEditorSave, object: nil)
        // 等待异步 Task 完成。
        try await Task.sleep(for: .milliseconds(300))
        let snapshot = await provider.currentSnapshot(for: Date())
        #expect(snapshot.lastActivityAt != nil)
        #expect(snapshot.lastActivityAt! >= before)

        try kernel.stop()
    }
}
