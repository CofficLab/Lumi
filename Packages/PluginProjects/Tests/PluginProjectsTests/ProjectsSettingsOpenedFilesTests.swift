import Foundation
import ProviderProject
import Testing
@testable import PluginProjects

/// 设置页的「Opened Files」区域必须跟随 Store 写入刷新，而不是停留在首次快照。
@MainActor
@Suite("ProjectsSettingsOpenedFiles")
struct ProjectsSettingsOpenedFilesTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsSettingsOpenedFiles-\(UUID().uuidString)")
    }

    @Test("Store 写入后 ViewModel 的打开文件缓存随之刷新")
    func openedFilesProjectionRefreshesWhenStoreChanges() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ProjectsStore(pluginDirectory: directory)
        let viewModel = ProjectsViewModel(
            store: store,
            projectCapability: ProjectsProjectCapabilityAdapter(project: DefaultProjectProvider())
        )
        viewModel.startObservingOpenedFiles()
        #expect(viewModel.openedFilesByPath.isEmpty)
        #expect(viewModel.isLoadingOpenedFiles == false)

        let key = ProjectsStore.normalizedPath("/tmp/demo")
        let file = URL(fileURLWithPath: "/tmp/demo/Sources/Main.swift")
        store.saveOpenedFiles([
            key: ProjectOpenedFiles(openFileURLs: [file], currentFileURL: file)
        ])
        #expect(viewModel.openedFilesByPath[key]?.openFileURLs == [file])

        // 关闭文件后再次写入：缓存必须回到空状态，而不是停留在首次快照。
        store.saveOpenedFiles([key: ProjectOpenedFiles()])
        #expect(viewModel.openedFilesByPath[key]?.openFileURLs == [])
    }

    @Test("preview-only 的当前文件不能被当成没有打开文件")
    func previewOnlyCurrentFileShowsActiveRow() {
        let preview = URL(fileURLWithPath: "/tmp/demo/Sources/Preview.swift")

        let state = SettingsView.openedFilesSectionState(
            isLoading: false,
            opened: ProjectOpenedFiles(openFileURLs: [], currentFileURL: preview)
        )
        #expect(state == .content(urls: [], current: preview))

        // 真正没有任何文件记录时才显示空态。
        let emptyState = SettingsView.openedFilesSectionState(
            isLoading: false,
            opened: ProjectOpenedFiles(openFileURLs: [], currentFileURL: nil)
        )
        #expect(emptyState == .empty)

        // 加载中优先于空态。
        let loadingState = SettingsView.openedFilesSectionState(
            isLoading: true,
            opened: ProjectOpenedFiles(openFileURLs: [], currentFileURL: nil)
        )
        #expect(loadingState == .loading)
    }
}
