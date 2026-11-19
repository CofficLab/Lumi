import Foundation
import KitAgentTool
import Testing
@testable import PluginAppIconDesigner

/// 回归 #1292：列表/写后刷新不应在主线程全量扫描解码文档目录；
/// 内存未命中时只按 ID 补载目标文档；目录无变化时跳过重复扫描。
@Suite("IconDocumentReloadOffMain")
struct IconDocumentReloadOffMainTests {
    private func makeDirectory(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("目录未变化时跳过全量扫描，变化后恢复扫描")
    @MainActor
    func unchangedDirectorySkipsFullRescan() throws {
        let directory = makeDirectory("IconStoreSkipTests")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IconDocumentStore()
        store.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)
        let initialScans = store.debugFullScanCount

        // 目录尚不存在：始终重扫（结果为空列表）。
        store.reload()
        #expect(store.debugFullScanCount == initialScans + 1)
        #expect(store.projectDocuments.isEmpty)

        let document = store.createDocument(
            title: "Skip", width: 512, height: 512,
            background: .color("#112233"), scope: .project
        )
        let afterCreate = store.debugFullScanCount

        // 落盘后目录已变化：恢复一次扫描并纳入文档。
        store.reload()
        #expect(store.debugFullScanCount == afterCreate + 1)
        #expect(store.projectDocuments.map(\.id) == [document.id])

        // 目录不再变化：连续重载不得重复扫描。
        store.reload()
        store.reload()
        #expect(store.debugFullScanCount == afterCreate + 1, "目录未变化时不得重复全量扫描")

        // 外部新增文件改变目录：恢复扫描并纳入新文档。
        let external = IconDocument(id: UUID().uuidString, title: "External")
        try IconDocumentFileStore.save(external, storagePath: directory.path)
        store.reload()
        #expect(store.debugFullScanCount == afterCreate + 2)
        #expect(store.projectDocuments.contains(where: { $0.id == external.id }))
    }

    @Test("applyReloaded 发布后台扫描结果并让下一次重载跳过扫描")
    @MainActor
    func applyReloadedPublishesBackgroundScan() throws {
        let directory = makeDirectory("IconStoreApplyTests")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IconDocumentStore()
        store.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)

        let first = IconDocument(id: UUID().uuidString, title: "First")
        let second = IconDocument(id: UUID().uuidString, title: "Second")
        try IconDocumentFileStore.save(first, storagePath: directory.path)
        try IconDocumentFileStore.save(second, storagePath: directory.path)

        // 模拟工具在主线程之外完成扫描后回主线程发布。
        let scan = IconDocumentFileStore.loadAllWithDirectoryModificationDate(
            storagePath: directory.path
        )
        store.applyReloaded(
            scan.documents, scope: .project,
            selectDocumentId: first.id,
            directoryModificationDate: scan.directoryModificationDate
        )
        #expect(store.projectDocuments.map(\.id).sorted() == [first.id, second.id].sorted())
        #expect(store.selectedDocumentId == first.id)

        // 发布时记录了目录 mtime：紧随其后的重载应跳过扫描。
        let beforeSkip = store.debugFullScanCount
        store.reload()
        #expect(store.debugFullScanCount == beforeSkip, "目录未变化时重载应跳过全量扫描")
        #expect(store.projectDocuments.count == 2)
    }

    @Test("loadDocument 只按 ID 补载目标文档，残留旧标题文件时取最新修订")
    func loadDocumentLoadsOnlyTargetID() throws {
        let directory = makeDirectory("IconLoadByIDTests")
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID().uuidString
        let other = IconDocument(id: UUID().uuidString, title: "Other")
        let older = IconDocument(id: id, title: "ZZZ", updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = IconDocument(id: id, title: "AAA", updatedAt: Date(timeIntervalSince1970: 2_000))
        try IconDocumentFileStore.save(other, storagePath: directory.path)
        try IconDocumentFileStore.save(older, storagePath: directory.path)
        try IconDocumentFileStore.save(newer, storagePath: directory.path)

        let loaded = IconDocumentFileStore.loadDocument(withID: id, storagePath: directory.path)
        #expect(loaded?.id == id)
        #expect(loaded?.title == "AAA", "同 ID 多文件时应取 updatedAt 最新的修订")

        #expect(IconDocumentFileStore.loadDocument(withID: UUID().uuidString, storagePath: directory.path) == nil)
        #expect(IconDocumentFileStore.loadDocument(withID: id, storagePath: "") == nil)
    }

    /// 通过 @TaskLocal 绑定对话项目（而非全局单例），断言全程不受并行
    /// 测试对 IconDesignerRuntime/IconDocumentStore.shared 的影响。
    @Test("工具路径：对话作用域下列表工具读磁盘、resolveDocument 磁盘补载")
    @MainActor
    func toolPathsReadDiskUnderConversationScope() async throws {
        let project = makeDirectory("IconToolPathsProject")
        defer { try? FileManager.default.removeItem(at: project) }
        let storage = IconDesignerRuntime.iconStorageDirectory(forProjectPath: project.path)!
        try IconDocumentFileStore.save(
            IconDocument(id: UUID().uuidString, title: "Fallback"), storagePath: storage.path
        )
        try IconDocumentFileStore.save(
            IconDocument(id: UUID().uuidString, title: "Beta"), storagePath: storage.path
        )

        let context = ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { project.path }
        )
        try await IconConversationProjectScope.$binding.withValue(.conversation(projectPath: project.path)) {
            // 列表工具以磁盘为准，输出全部文档摘要。
            let listResult = try await ConversationScopedIconTool(ListIconDocumentsTool())
                .executeResult(context: context, arguments: [:])
            #expect(listResult.content.contains("documentId="))
            #expect(listResult.content.contains("title="))

            // 列表调用后落盘的新文档不在 scoped store 内存里：
            // resolveDocument 必须按 ID 从磁盘补载。
            let late = IconDocument(id: UUID().uuidString, title: "Late")
            try IconDocumentFileStore.save(late, storagePath: storage.path)
            let resolved = try await IconToolSupport.resolveDocument([
                "documentId": ToolArgument(late.id)
            ])
            #expect(resolved.0.id == late.id)
            #expect(resolved.0.title == "Late")

            do {
                _ = try await IconToolSupport.resolveDocument([
                    "documentId": ToolArgument(UUID().uuidString)
                ])
                Issue.record("不存在的 documentId 应抛错")
            } catch let error as IconDocumentStoreError {
                #expect(error == .documentNotFound(error.errorText))
            }
        }
    }
}

private extension IconDocumentStoreError {
    var errorText: String {
        switch self {
        case .documentNotFound(let id): return id
        default: return ""
        }
    }
}
