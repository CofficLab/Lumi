import Foundation
import KitPrototype
import Testing
@testable import PluginPrototypeDesigner

/// 复现「每次轨道点击都在主线程重列全部原型项目并重读屏幕 HTML」。
///
/// 原先 `select(projectID:screenID:)` 直接调用 `reload()`：一次点击 =
/// 枚举存储目录 + 解码所有项目 manifest + 再解码选中项目 manifest + 整份 HTML。
/// 现在选中只刷新选中屏幕：复用列表已解码的 manifest（`readScreen(project:)`），
/// 同一屏已加载时直接短路。
///
/// 这些用例改动全局 `WorkspaceStore.shared` 与 `PrototypeDesignerRuntime`，
/// 以扩展形式并入已标记 `.serialized` 的插件主测试套件。
extension PrototypeDesignerPluginTests {
    /// 构造一个临时项目根目录并激活存储。
    private func makeSelectionProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-selection-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func activateSelectionStorage(for root: URL) {
        PrototypeDesignerRuntime.reset()
        let storage = root
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PrototypeDesignerRuntime.projectFolderName, isDirectory: true)
        PrototypeDesignerRuntime.setProjectStorage(projectPath: root.path, projectStorageDirectory: storage)
    }

    private func createSelectionProject(
        slug: String,
        screens: [String],
        storagePath: String
    ) throws {
        let device = try #require(PrototypeDeviceKind.iPhone15Pro.preset)
        _ = try WorkspaceStore.shared.documentStore.createProject(
            storagePath: storagePath,
            slug: slug,
            title: slug,
            style: .hiFi,
            device: device
        )
        for screen in screens {
            _ = try WorkspaceStore.shared.documentStore.addScreen(
                storagePath: storagePath,
                projectSlug: slug,
                screenSlug: screen,
                title: screen
            )
        }
    }

    @Test("选中屏幕不重扫项目目录")
    func selectionDoesNotRescanProjectCatalog() throws {
        let root = try makeSelectionProjectRoot("catalog")
        defer {
            PrototypeDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: root)
        }
        activateSelectionStorage(for: root)
        try createSelectionProject(slug: "project-a", screens: ["alpha", "beta"], storagePath: WorkspaceStore.shared.projectStoragePath)
        try createSelectionProject(slug: "project-b", screens: ["gamma"], storagePath: WorkspaceStore.shared.projectStoragePath)
        WorkspaceStore.shared.reload()
        #expect(WorkspaceStore.shared.projects.count == 2)

        // 在列表加载后往磁盘外部新增第三个项目：若 select 仍整目录重扫，
        // 列表会变成 3 项；正确行为是保持 2 项。
        try createSelectionProject(slug: "project-c", screens: ["delta"], storagePath: WorkspaceStore.shared.projectStoragePath)
        WorkspaceStore.shared.select(projectID: "project-a", screenID: nil)

        #expect(WorkspaceStore.shared.projects.count == 2)
        #expect(WorkspaceStore.shared.selectedScreen?.screen.id == "alpha")
    }

    @Test("重复选中同一屏不再重读 HTML")
    func repeatedSelectionOfSameScreenDoesNotRereadHTML() throws {
        let root = try makeSelectionProjectRoot("reread")
        defer {
            PrototypeDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: root)
        }
        activateSelectionStorage(for: root)
        try createSelectionProject(slug: "project-a", screens: ["alpha"], storagePath: WorkspaceStore.shared.projectStoragePath)
        WorkspaceStore.shared.reload()

        WorkspaceStore.shared.select(projectID: "project-a", screenID: "alpha")
        let originalHTML = try #require(WorkspaceStore.shared.selectedScreen?.html)

        // 破坏磁盘上的 HTML：若 select 仍重读文件，缓存会被 "corrupted" 覆盖。
        let htmlURL = try #require(WorkspaceStore.shared.selectedScreen?.htmlURL)
        try "corrupted".write(to: htmlURL, atomically: true, encoding: .utf8)

        WorkspaceStore.shared.select(projectID: "project-a", screenID: "alpha")
        #expect(WorkspaceStore.shared.selectedScreen?.html == originalHTML)
    }

    @Test("切换屏幕仍会加载新屏幕的 HTML")
    func selectingAnotherScreenStillLoadsItsHTML() throws {
        let root = try makeSelectionProjectRoot("switch")
        defer {
            PrototypeDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: root)
        }
        activateSelectionStorage(for: root)
        try createSelectionProject(slug: "project-a", screens: ["alpha", "beta"], storagePath: WorkspaceStore.shared.projectStoragePath)
        WorkspaceStore.shared.reload()

        WorkspaceStore.shared.select(projectID: "project-a", screenID: "alpha")
        #expect(WorkspaceStore.shared.selectedScreen?.screen.id == "alpha")

        WorkspaceStore.shared.select(projectID: "project-a", screenID: "beta")
        #expect(WorkspaceStore.shared.selectedScreen?.screen.id == "beta")
    }

    @Test("加载失败后再次选中会重试")
    func failedSelectionRetriesOnNextSelect() throws {
        let root = try makeSelectionProjectRoot("retry")
        defer {
            PrototypeDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: root)
        }
        activateSelectionStorage(for: root)
        // 用独立的 slug：套件串行共享全局 WorkspaceStore，先前用例可能遗留
        // 同名项目的选中态；独立 slug 保证本用例从「未选中」开始。
        try createSelectionProject(slug: "retry-project", screens: ["alpha"], storagePath: WorkspaceStore.shared.projectStoragePath)
        WorkspaceStore.shared.reload()

        let original = try WorkspaceStore.shared.documentStore.readScreen(
            storagePath: WorkspaceStore.shared.projectStoragePath,
            projectSlug: "retry-project",
            screenSlug: "alpha"
        )
        try FileManager.default.removeItem(at: original.htmlURL)

        // 首次选中失败：selectedScreen 为空，不得缓存失败结果。
        WorkspaceStore.shared.select(projectID: "retry-project", screenID: "alpha")
        #expect(WorkspaceStore.shared.selectedScreen == nil)

        try original.html.write(to: original.htmlURL, atomically: true, encoding: .utf8)
        WorkspaceStore.shared.select(projectID: "retry-project", screenID: "alpha")
        #expect(WorkspaceStore.shared.selectedScreen?.screen.id == "alpha")
    }

    @Test("热点指向未知屏幕时保持当前选中不变（#323）")
    func hotspotTargetToUnknownScreenKeepsCurrentSelection() throws {
        let root = try makeSelectionProjectRoot("hotspot")
        defer {
            PrototypeDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: root)
        }
        activateSelectionStorage(for: root)
        try createSelectionProject(slug: "hotspot-project", screens: ["alpha", "beta"], storagePath: WorkspaceStore.shared.projectStoragePath)
        WorkspaceStore.shared.reload()

        let project = try #require(WorkspaceStore.shared.projects.first(where: { $0.id == "hotspot-project" }))
        WorkspaceStore.shared.select(projectID: project.id, screenID: "beta")

        // 未知目标必须被忽略：refreshSelectedScreen 对未知 ID 会回退到第一屏
        // （alpha），直接复用 select 会让坏热点意外跳到起始屏。
        WorkspaceStore.shared.selectHotspotTarget("unknown-screen", in: project)
        #expect(WorkspaceStore.shared.selectedScreen?.screen.id == "beta")

        WorkspaceStore.shared.selectHotspotTarget("alpha", in: project)
        #expect(WorkspaceStore.shared.selectedScreen?.screen.id == "alpha")
    }
}
