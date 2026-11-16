import Foundation
import KernelCore
import ProviderPanelBottom
import ProviderProject
import ProviderRootView
import Testing
@testable import PluginEditorPreview

/// 回归 #364：Editor Preview 被禁用后，切换文件或项目都不得重新注册 Preview 入口。
///
/// `onDisable` 原先只撤回入口，却没有记录禁用态；项目观察者仍然存活，
/// 选中可预览文件时回调 `updateFooterTab` 又把入口加了回来。修复后由
/// `isEnabled` 守卫注册决策，只有重新 `onEnable` 才恢复。
@MainActor
@Suite("Editor Preview 插件生命周期（回归 #364）", .serialized)
struct EditorPreviewPluginLifecycleTests {

    private struct Harness {
        let kernel: KernelCoreContainer
        let project: DefaultProjectProvider
        let panelBottom: PanelBottomProvider
        let plugin: EditorPreviewPlugin
    }

    private func makeHarness() throws -> Harness {
        let kernel = KernelCoreContainer()
        let project = DefaultProjectProvider()
        let rootView = DefaultRootViewProviding()
        let panelBottom = PanelBottomProvider()
        try kernel.registerProvider((any ProjectProviding).self, project)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any PanelBottomProviding).self, panelBottom)
        let plugin = EditorPreviewPlugin()
        try plugin.onBoot(kernel: kernel)
        return Harness(kernel: kernel, project: project, panelBottom: panelBottom, plugin: plugin)
    }

    private func previewItemCount(_ panelBottom: PanelBottomProvider) -> Int {
        panelBottom.items.filter { $0.ownerPluginID == EditorPreviewPlugin.pluginID }.count
    }

    private func makeMarkdown(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-preview-364-\(UUID().uuidString)-\(name).md")
        try Data("# \(name)\n".utf8).write(to: url)
        return url
    }

    @Test("禁用后切换文件不得重新注册 Preview 入口")
    func disabledPluginDoesNotReRegisterOnFileSwitch() async throws {
        let h = try makeHarness()
        defer { try? h.plugin.onShutdown(kernel: h.kernel) }
        let a = try makeMarkdown("A")
        let b = try makeMarkdown("B")
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }

        // 选中可预览文件 → 注册入口（Markdown 同步进入 .loading，showsPreviewFooter 为真）。
        h.project.updateCurrentFile(a)
        #expect(previewItemCount(h.panelBottom) == 1)

        // 禁用 → 撤回入口。
        try await h.plugin.onDisable(kernel: h.kernel)
        #expect(previewItemCount(h.panelBottom) == 0)

        // 切换到另一个可预览文件：禁用期间不得把入口加回来。
        h.project.updateCurrentFile(b)
        #expect(previewItemCount(h.panelBottom) == 0)
    }

    @Test("重新启用后恢复 Preview 入口")
    func enableRestoresPreviewTab() async throws {
        let h = try makeHarness()
        defer { try? h.plugin.onShutdown(kernel: h.kernel) }
        let a = try makeMarkdown("A")
        defer { try? FileManager.default.removeItem(at: a) }

        h.project.updateCurrentFile(a)
        #expect(previewItemCount(h.panelBottom) == 1)

        try await h.plugin.onDisable(kernel: h.kernel)
        #expect(previewItemCount(h.panelBottom) == 0)

        // 重新启用：按当前文件恢复入口。
        try await h.plugin.onEnable(kernel: h.kernel)
        #expect(previewItemCount(h.panelBottom) == 1)
    }

    @Test("禁用后切换项目不得重新注册 Preview 入口")
    func disabledPluginDoesNotReRegisterOnProjectChange() async throws {
        let h = try makeHarness()
        defer { try? h.plugin.onShutdown(kernel: h.kernel) }
        let a = try makeMarkdown("A")
        defer { try? FileManager.default.removeItem(at: a) }

        h.project.updateCurrentFile(a)
        #expect(previewItemCount(h.panelBottom) == 1)

        try await h.plugin.onDisable(kernel: h.kernel)
        #expect(previewItemCount(h.panelBottom) == 0)

        // 切换项目会触发 .currentProjectChanged，观察者按当前文件重新决策注册。
        try await h.project.openProject(at: "/tmp/lumi-preview-364-project")
        #expect(previewItemCount(h.panelBottom) == 0)
    }
}