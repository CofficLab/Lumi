import Foundation
import ProviderProject
import Testing
@testable import PluginProjects

/// 存储状态刷新通道测试。
///
/// 项目目录是否仍在磁盘上会随外部操作变化，探测结果按路径缓存；
/// 因此「刷新」必须同时做到两件事：清空缓存、递增修订号驱动视图重绘。
@MainActor
@Suite("项目存储状态刷新", .serialized)
struct ProjectStorageRefreshTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsStorageRefresh-\(UUID().uuidString)")
    }

    private func makeViewModel() -> ProjectsViewModel {
        ProjectsViewModel(
            store: ProjectsStore(pluginDirectory: temporaryDirectory()),
            projectCapability: ProjectsProjectCapabilityAdapter(project: DefaultProjectProvider())
        )
    }

    @Test("刷新会递增存储状态修订号")
    func refreshIncrementsRevision() {
        let viewModel = makeViewModel()
        #expect(viewModel.storageRevision == 0)

        viewModel.refreshStorageState()
        #expect(viewModel.storageRevision == 1)

        viewModel.refreshStorageState()
        #expect(viewModel.storageRevision == 2)
    }

    /// 刷新必须清空探测缓存，否则目录删除后视图仍显示旧状态。
    @Test("刷新会清空探测缓存")
    func refreshInvalidatesDetectorCache() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let viewModel = makeViewModel()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        ProjectStorageDetector.invalidateAll()
        #expect(ProjectStorageDetector.kind(for: directory.path) == .internalDisk)

        try? FileManager.default.removeItem(at: directory)

        // 未刷新时缓存仍返回旧结果。
        #expect(ProjectStorageDetector.kind(for: directory.path) == .internalDisk)

        // 刷新后重新探测，能看到目录已从磁盘上消失。
        viewModel.refreshStorageState()
        #expect(ProjectStorageDetector.kind(for: directory.path) == .missingDirectory)
    }

    /// 提示文案只覆盖「项目不可用」的两种状态，正常状态不打扰用户。
    @Test("仅不可用状态给出提示文案")
    func hintOnlyForUnavailableStates() {
        #expect(!ProjectStorageHint.text(for: .missingDirectory).isEmpty)
        #expect(!ProjectStorageHint.text(for: .unreachableVolume).isEmpty)
        #expect(ProjectStorageHint.text(for: .internalDisk).isEmpty)
        #expect(ProjectStorageHint.text(for: .externalDisk).isEmpty)
        #expect(ProjectStorageHint.text(for: .networkVolume).isEmpty)
    }
}
