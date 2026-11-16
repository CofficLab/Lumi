import Combine
import Foundation
import ProviderProject
import Testing
@testable import PluginProjectFiles

/// tab 投影的三道守卫（回归 #1239）。
///
/// Project Files 是必需插件，旧实现对**每个**项目事件都重建 O(F²) 的 tab 投影
/// 并无条件发布 `@Published`，即使投影完全没变——无关的项目列表事件和普通文件
/// 导航都会白白触发一次非懒加载 `HStack` 的全量布局。
///
/// 这里锁住：事件过滤、发布前的等值比较、以及去重的顺序与幂等语义。
@MainActor
@Suite("Project Files tab 投影守卫")
struct ProjectFilesTabProjectionGuardsTests {
    /// 可记录调用的项目能力替身。
    private final class StubCapability: ProjectFilesProjectCapability {
        var currentProject: ProjectInfo?
        var openFileURLs: [URL] = []
        var currentFileURL: URL?

        func activateFile(_ fileURL: URL) {}
        func closeFile(_ fileURL: URL) {}
        func updateCurrentFile(_ fileURL: URL?) {}
    }

    /// 事件回调计数。observer 的回调是同步非 Sendable 闭包，用局部类装计数。
    private final class ReloadCounter {
        var count = 0
    }

    @Test("项目列表变化不触发 tab 重载")
    func projectsChangedDoesNotReloadTabs() {
        let project = DefaultProjectProvider()
        let viewModel = ProjectFilesTabViewModel(
            projectCapability: ProjectFilesProjectCapabilityAdapter(project: project)
        )
        let counter = ReloadCounter()
        // 与插件入口一致：Observer 驱动 ViewModel reload，同时记录回调次数。
        let observer = ProjectFilesProjectObserver(project: project) { [counter, weak viewModel] in
            counter.count += 1
            viewModel?.reload()
        }
        defer { observer.cancel() }

        project.pinFile(URL(fileURLWithPath: "/tmp/A.swift"))
        let baseline = counter.count
        #expect(baseline > 0)
        #expect(viewModel.tabState.fileURLs.count == 1)

        // 只改项目列表：openFileURLs / currentFileURL 都没动。
        project.synchronizeProjects([ProjectInfo(name: "Other", path: "/tmp/other")])

        #expect(counter.count == baseline)
        #expect(viewModel.tabState.fileURLs.count == 1)
    }

    @Test("打开文件、当前文件与当前项目变化仍触发重载")
    func fileAndProjectEventsStillReloadTabs() async throws {
        let project = DefaultProjectProvider()
        let viewModel = ProjectFilesTabViewModel(
            projectCapability: ProjectFilesProjectCapabilityAdapter(project: project)
        )
        let counter = ReloadCounter()
        let observer = ProjectFilesProjectObserver(project: project) { [counter, weak viewModel] in
            counter.count += 1
            viewModel?.reload()
        }
        defer { observer.cancel() }

        let first = URL(fileURLWithPath: "/tmp/A.swift")
        let second = URL(fileURLWithPath: "/tmp/B.swift")

        project.pinFile(first)
        let afterPin = counter.count
        #expect(afterPin > 0)

        project.updateCurrentFile(second)
        #expect(counter.count > afterPin)
        #expect(viewModel.tabState.activeFileURL == second.standardizedFileURL)

        let afterCurrentFile = counter.count
        try await project.openProject(at: "/tmp/demo")
        #expect(counter.count > afterCurrentFile)
    }

    @Test("投影未变化时 reload 不发布新值")
    func unchangedProjectionDoesNotPublish() {
        let capability = StubCapability()
        let first = URL(fileURLWithPath: "/tmp/A.swift")
        let second = URL(fileURLWithPath: "/tmp/B.swift")
        capability.openFileURLs = [first, second]
        capability.currentFileURL = second
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)

        nonisolated(unsafe) var emissions = 0
        let cancellable = viewModel.objectWillChange.sink { _ in emissions += 1 }
        defer { cancellable.cancel() }

        viewModel.reload()
        viewModel.reload()
        #expect(emissions == 0)

        capability.openFileURLs = [first, second, URL(fileURLWithPath: "/tmp/C.swift")]
        viewModel.reload()
        #expect(emissions == 1)
        #expect(viewModel.tabState.fileURLs.count == 3)
    }

    @Test("大量重复 URL 去重后保持原有顺序")
    func duplicateHeavyInputKeepsOrderAndUniqueness() {
        let base = (0..<300).map { URL(fileURLWithPath: "/tmp/project/File\($0).swift") }
        // 每个文件出现三次，其中一次带需要标准化才能识别的 `..` 片段。
        let noisy = base.flatMap { url -> [URL] in
            let indirect = URL(fileURLWithPath: "/tmp/project/sub/../\(url.lastPathComponent)")
            return [url, indirect, url]
        }

        let state = ProjectFilesTabState(openFileURLs: noisy, currentFileURL: base[7])

        #expect(state.fileURLs == base.map(\.standardizedFileURL))
        #expect(state.currentFileURL == base[7].standardizedFileURL)
    }
}