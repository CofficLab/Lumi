import Foundation
import KernelCore
import ProviderProject
import ProviderRootView
import Testing
@testable import PluginProjectFiles

// MARK: - 测试替身

/// 可记录调用的项目能力替身。
@MainActor
private final class StubProjectCapability: ProjectFilesProjectCapability {
    var currentProject: ProjectInfo?
    var openFileURLs: [URL] = []
    var currentFileURL: URL?

    private(set) var activatedFiles: [URL] = []
    private(set) var closedFiles: [URL] = []
    private(set) var currentFileUpdates: [URL?] = []

    func activateFile(_ fileURL: URL) {
        activatedFiles.append(fileURL)
    }

    func closeFile(_ fileURL: URL) {
        closedFiles.append(fileURL)
    }

    func updateCurrentFile(_ fileURL: URL?) {
        currentFileUpdates.append(fileURL)
    }
}

// MARK: - ViewModel

@Suite("Project Files ViewModel")
@MainActor
struct ProjectFilesTabViewModelTests {

    @Test("reload 重新读取打开文件")
    func reloadPicksUpNewFiles() {
        let capability = StubProjectCapability()
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)
        #expect(viewModel.tabState.fileURLs.isEmpty)

        capability.openFileURLs = [URL(fileURLWithPath: "/tmp/A.swift")]
        viewModel.reload()

        #expect(viewModel.tabState.fileURLs == [URL(fileURLWithPath: "/tmp/A.swift")])
    }

    @Test("activate 转发给能力层")
    func activateForwardsToCapability() {
        let capability = StubProjectCapability()
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)
        let file = URL(fileURLWithPath: "/tmp/A.swift")

        viewModel.activate(file)

        #expect(capability.activatedFiles == [file])
    }

    @Test("close 关闭文件并清空指向该文件的当前文件")
    func closeClearsCurrentFileWhenNotPinned() {
        let capability = StubProjectCapability()
        let file = URL(fileURLWithPath: "/tmp/A.swift")
        capability.openFileURLs = []
        capability.currentFileURL = file
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)

        viewModel.close(file)

        #expect(capability.closedFiles == [file])
        #expect(capability.currentFileUpdates == [nil])
    }

    @Test("close 仍在打开列表中的文件时保留当前文件")
    func closeKeepsCurrentFileWhenPinned() {
        let capability = StubProjectCapability()
        let file = URL(fileURLWithPath: "/tmp/A.swift")
        capability.openFileURLs = [file]
        capability.currentFileURL = file
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)

        viewModel.close(file)

        #expect(capability.closedFiles == [file])
        #expect(capability.currentFileUpdates.isEmpty)
    }

    @Test("closeOthers 只关闭其它文件")
    func closeOthersKeepsGivenFile() {
        let capability = StubProjectCapability()
        let keep = URL(fileURLWithPath: "/tmp/A.swift")
        let other = URL(fileURLWithPath: "/tmp/B.swift")
        capability.openFileURLs = [keep, other]
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)

        viewModel.closeOthers(keeping: keep)

        #expect(capability.closedFiles == [other])
    }

    @Test("projectIsOpen 跟随当前项目")
    func projectIsOpenFollowsCurrentProject() {
        let capability = StubProjectCapability()
        let viewModel = ProjectFilesTabViewModel(projectCapability: capability)
        #expect(viewModel.projectIsOpen == false)

        capability.currentProject = ProjectInfo(
            name: "Demo",
            path: "/tmp/demo"
        )
        viewModel.reload()

        #expect(viewModel.projectIsOpen)
    }
}

// MARK: - 插件生命周期

@Suite("Project Files 插件生命周期")
@MainActor
struct ProjectFilesPluginLifecycleTests {

    @Test("启动后注册 content header 且无文件时隐藏")
    func bootHidesHeaderWithoutFiles() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, DefaultProjectProvider())
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = ProjectFilesPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        #expect(rootView.contentHeaderView != nil)
        #expect(rootView.isContentHeaderViewHidden)
    }

    @Test("有打开文件时显示 content header")
    func bootShowsHeaderWithFiles() throws {
        let kernel = KernelCoreContainer()
        let project = DefaultProjectProvider()
        project.pinFile(URL(fileURLWithPath: "/tmp/A.swift"))
        try kernel.registerProvider((any ProjectProviding).self, project)
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = ProjectFilesPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        #expect(rootView.isContentHeaderViewHidden == false)
    }

    @Test("缺少项目 Provider 时启动失败")
    func bootFailsWithoutProjectProvider() {
        let kernel = KernelCoreContainer()

        #expect(throws: (any Error).self) {
            try ProjectFilesPlugin().onBoot(kernel: kernel)
        }
    }

    @Test("缺少根视图 Provider 时启动失败")
    func bootFailsWithoutRootViewProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, DefaultProjectProvider())

        #expect(throws: (any Error).self) {
            try ProjectFilesPlugin().onBoot(kernel: kernel)
        }
    }

    @Test("关闭时清空 content header")
    func shutdownClearsContentHeader() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, DefaultProjectProvider())
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = ProjectFilesPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(rootView.contentHeaderView == nil)
    }
}
