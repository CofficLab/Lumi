import Combine
import Foundation

/// App Icon 设计器的唯一数据来源（DesignerView / RailView 共用）。
///
/// 包装 `IconDocumentStore`：文档列表、选中文档/图层、导出与错误状态全部
/// 经本 ViewModel 发布；项目外部变化由 `IconDesignerProjectObserver` 直接
/// 写入本 ViewModel，View 不再接触 Store 或外部状态。
@MainActor
final class AppIconDesignerViewModel: ObservableObject {
    private let store: IconDocumentStore
    private var cancellable: AnyCancellable?

    // MARK: - Published State (供 View 展示)

    @Published private(set) var projectDocuments: [IconDocument] = []
    @Published private(set) var appDocuments: [IconDocument] = []
    @Published private(set) var selectedScope: IconScope = .app
    @Published private(set) var selectedDocumentId: String?
    @Published private(set) var lastExportURL: URL?
    @Published private(set) var lastError: String?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var appStoragePath = ""
    @Published private(set) var projectStoragePath = ""
    @Published private(set) var currentProjectPath: String?

    init(store: IconDocumentStore) {
        self.store = store
        syncFromStore()
        cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.syncFromStore()
        }
    }

    // MARK: - 派生状态

    var selectedDocument: IconDocument? {
        store.selectedDocument
    }

    /// 当前作用域下的文档列表（向后兼容入口）。
    var documents: [IconDocument] {
        store.documents
    }

    func documents(for scope: IconScope) -> [IconDocument] {
        store.documents(for: scope)
    }

    var storagePath: String {
        store.storagePath
    }

    func storagePath(for scope: IconScope) -> String {
        store.storagePath(for: scope)
    }

    var totalCount: Int {
        projectDocuments.count + appDocuments.count
    }

    // MARK: - Observer 写入

    /// 当前项目变化时由 `IconDesignerProjectObserver` 调用。
    func handleCurrentProjectChange(path: String?) {
        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: path)
    }

    // MARK: - 用户意图

    func reload() {
        store.reload()
    }

    func reloadScope(_ scope: IconScope) {
        store.reloadScope(scope)
    }

    func reload(scope: IconScope, selectDocumentId documentId: String? = nil) {
        store.reload(scope: scope, selectDocumentId: documentId)
    }

    func createDocument(title: String?, width: Double, height: Double, background: IconPaint, scope: IconScope) {
        store.createDocument(
            title: title,
            width: width,
            height: height,
            background: background,
            scope: scope
        )
    }

    func selectDocument(id: String, scope: IconScope) throws {
        try store.selectDocument(id: id, scope: scope)
    }

    func deleteDocument(id: String, scope: IconScope) {
        store.deleteDocument(id: id, scope: scope)
    }

    func setExportURL(_ url: URL) {
        store.setExportURL(url)
    }

    func setError(_ message: String) {
        store.setError(message)
    }

    func undo() {
        store.undo()
    }

    func redo() {
        store.redo()
    }

    // MARK: - Private

    private func syncFromStore() {
        projectDocuments = store.projectDocuments
        appDocuments = store.appDocuments
        selectedScope = store.selectedScope
        selectedDocumentId = store.selectedDocumentId
        lastExportURL = store.lastExportURL
        lastError = store.lastError
        canUndo = store.canUndo
        canRedo = store.canRedo
        appStoragePath = store.appStoragePath
        projectStoragePath = store.projectStoragePath
        currentProjectPath = store.currentProjectPath
    }
}
