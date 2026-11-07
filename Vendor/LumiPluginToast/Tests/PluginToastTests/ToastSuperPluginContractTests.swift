import KernelCore
import ProviderDocsView
import ProviderToast
import SwiftUI
import XCTest
@testable import PluginToast

/// 插件生命周期契约：注册表替换、Docs 条目注入、关闭时清理。
@MainActor
final class ToastSuperPluginContractTests: XCTestCase {

    func testMetadataInvariants() {
        let plugin = ToastSuperPlugin()

        XCTAssertEqual(plugin.id, "com.coffic.lumi.plugin.toast")
        XCTAssertEqual(plugin.metadata.id, plugin.id)
        XCTAssertEqual(plugin.order, 10)
        XCTAssertEqual(plugin.metadata.category, .core)
        XCTAssertEqual(plugin.metadata.stage, .stable)
        XCTAssertEqual(plugin.metadata.policy, .required)
        XCTAssertEqual(ToastSuperPlugin.overlayID, "lumi-plugin-toast", "根覆盖层应使用稳定的挂载标识")
    }

    func testCustomIDIsApplied() {
        let plugin = ToastSuperPlugin(id: "com.example.custom.plugin.toast")

        XCTAssertEqual(plugin.id, "com.example.custom.plugin.toast")
        XCTAssertEqual(plugin.metadata.id, plugin.id)
        XCTAssertEqual(ToastSuperPlugin.defaultPluginID, "com.coffic.lumi.plugin.toast")
    }

    func testDoubleBootDoesNotThrowAndKeepsSingleProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = ToastSuperPlugin()

        try plugin.onBoot(kernel: kernel)
        try plugin.onBoot(kernel: kernel)

        XCTAssertTrue(kernel.resolveProvider((any ToastProviding).self) === plugin.center)
    }

    func testOnRegisterAddsAboutEntryToDocsProvider() throws {
        let kernel = KernelCoreContainer()
        let docs = FakeDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = ToastSuperPlugin()
        try plugin.onRegister(kernel: kernel)

        XCTAssertEqual(docs.aboutEntries.count, 1)
        XCTAssertEqual(docs.aboutEntries.first?.id, plugin.id)
        XCTAssertEqual(docs.aboutEntries.first?.name, plugin.metadata.name)

        try plugin.onUnregister(kernel: kernel)
        XCTAssertTrue(docs.aboutEntries.isEmpty, "卸载时应移除本插件的关于条目")
    }

    func testOnUnregisterRemovesOnlyOwnEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = FakeDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        docs.aboutEntries = [
            DocsEntry(id: "com.coffic.lumi.plugin.toast", name: "Toast") { Color.clear },
            DocsEntry(id: "com.other.plugin", name: "Other") { Color.clear },
        ]

        let plugin = ToastSuperPlugin()
        try plugin.onUnregister(kernel: kernel)

        XCTAssertEqual(docs.aboutEntries.map(\.id), ["com.other.plugin"], "只能移除自己的条目")
    }

    func testOnShutdownDismissesCenterStateAndUninstallsOverlay() throws {
        let kernel = KernelCoreContainer()
        var isMounted = true
        let plugin = ToastSuperPlugin(
            overlayInstaller: { _, _ in isMounted = true },
            overlayUninstaller: { _ in isMounted = false }
        )
        try plugin.onBoot(kernel: kernel)

        plugin.center.show(LumiToast(title: "T", style: .info))
        plugin.center.presentError(title: "E", message: "m")
        plugin.center.showLoading(title: "L", detail: nil)

        try plugin.onShutdown(kernel: kernel)

        XCTAssertNil(plugin.center.currentToast, "关闭时残留 toast 应被清除")
        XCTAssertNil(plugin.center.currentError, "关闭时残留错误应被清除")
        XCTAssertNil(plugin.center.currentLoading, "关闭时残留 loading 应被清除")
        XCTAssertFalse(isMounted, "关闭时应调用覆盖层卸载器")
    }
}

/// 最小 `DocsViewProviding` 测试替身。
@MainActor
private final class FakeDocsViewProviding: DocsViewProviding {
    var aboutEntries: [DocsEntry] = []
    var manualEntries: [DocsEntry] = []

    func replaceAboutEntries(_ entries: [DocsEntry]) {
        aboutEntries = entries
    }

    func replaceManualEntries(_ entries: [DocsEntry]) {
        manualEntries = entries
    }
}
