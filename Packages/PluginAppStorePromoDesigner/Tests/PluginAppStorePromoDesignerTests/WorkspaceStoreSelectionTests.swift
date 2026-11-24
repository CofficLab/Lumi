import KitAppStorePromo
import Foundation
import Testing
@testable import PluginAppStorePromoDesigner

/// 选中任务/图像行的开销（见 issue #1178）。
///
/// 原先每次 `select` 都无条件 `reload()`：在主线程枚举并解码全部任务
/// manifest，再重复读取选中任务的 manifest 与 HTML，点击延迟随任务数增长。
///
/// 这些用例会改动全局 `WorkspaceStore.shared`，因此以扩展形式并入
/// 插件主测试套件（已标记 `.serialized`），与其他改动同一全局状态的
/// 用例串行执行，避免并行时互相污染。
extension AppStorePromoDesignerPluginTests {

    private func makeSelectionProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("promo-select-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func activateStorage(for project: URL) {
        PromoDesignerRuntime.reset()
        let storage = project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
        PromoDesignerRuntime.setProjectStorage(projectPath: project.path, projectStorageDirectory: storage)
    }

    /// 创建一个带单张图像的任务。
    private func createTaskWithImage(slug: String, in workspace: WorkspaceStore) throws {
        _ = try workspace.documentStore.createTask(
            storagePath: workspace.projectStoragePath,
            slug: slug,
            title: slug,
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )
        _ = try workspace.documentStore.createImage(
            storagePath: workspace.projectStoragePath,
            taskSlug: slug,
            imageSlug: "shot",
            title: "Shot"
        )
    }

    @Test("选中任务不重扫任务目录，外部新增的任务不因此进入列表")
    func selectionDoesNotRescanTaskCatalog() throws {
        let project = try makeSelectionProjectRoot("rescan")
        defer { try? FileManager.default.removeItem(at: project) }
        activateStorage(for: project)
        let workspace = WorkspaceStore.shared
        try createTaskWithImage(slug: "task-a", in: workspace)
        try createTaskWithImage(slug: "task-b", in: workspace)
        workspace.reload()
        #expect(workspace.projectTasks.count == 2)

        // 磁盘上外部新增第三个任务：选中不应触发重扫，列表保持旧快照。
        _ = try workspace.documentStore.createTask(
            storagePath: workspace.projectStoragePath,
            slug: "task-c",
            title: "Task C",
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )
        workspace.select(taskID: "task-a", imageID: nil)

        #expect(workspace.projectTasks.count == 2)
        #expect(!workspace.projectTasks.contains { $0.id == "task-c" })
        #expect(workspace.selectedImage?.task.id == "task-a")
    }

    @Test("重复选中同一行不重新读取图像")
    func repeatedSelectionOfSameRowDoesNotRereadImage() throws {
        let project = try makeSelectionProjectRoot("repeat")
        defer { try? FileManager.default.removeItem(at: project) }
        activateStorage(for: project)
        let workspace = WorkspaceStore.shared
        try createTaskWithImage(slug: "task-a", in: workspace)
        workspace.reload()
        workspace.select(taskID: "task-a", imageID: nil)
        let loaded = try #require(workspace.selectedImage)
        let originalHTML = loaded.html

        // 磁盘上的 HTML 被外部改写：重复选中同一行不应再读盘。
        try "corrupted".write(to: loaded.htmlURL, atomically: true, encoding: .utf8)
        workspace.select(taskID: "task-a", imageID: nil)

        #expect(workspace.selectedImage?.html == originalHTML)
    }

    @Test("选中另一个任务仍会加载其图像")
    func selectingAnotherTaskStillLoadsItsImage() throws {
        let project = try makeSelectionProjectRoot("switch")
        defer { try? FileManager.default.removeItem(at: project) }
        activateStorage(for: project)
        let workspace = WorkspaceStore.shared
        try createTaskWithImage(slug: "task-a", in: workspace)
        try createTaskWithImage(slug: "task-b", in: workspace)
        workspace.reload()
        workspace.select(taskID: "task-a", imageID: nil)
        #expect(workspace.selectedImage?.task.id == "task-a")

        workspace.select(taskID: "task-b", imageID: nil)
        #expect(workspace.selectedImage?.task.id == "task-b")
        #expect(workspace.projectTasks.contains { $0.id == "task-b" })
    }
}
