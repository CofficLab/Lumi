import Foundation

@MainActor
public final class IconDocumentStore: ObservableObject {
    public static let shared = IconDocumentStore()

    /// 项目内（当前打开项目 `.lumi/app-icon-designer`）文档列表。
    @Published public private(set) var projectDocuments: [IconDocument] = []

    /// APP 内（应用数据目录）文档列表。
    @Published public private(set) var appDocuments: [IconDocument] = []

    /// 当前选中的作用域。
    @Published public var selectedScope: IconScope = .app

    @Published public var selectedDocumentId: String?
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastError: String?
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false

    private var undoStack: [IconDocument] = []
    private var redoStack: [IconDocument] = []
    private(set) var appStorageDirectory: URL?
    private(set) var projectStorageDirectory: URL?
    private(set) var currentProjectPath: String?
    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Lists

    /// 当前选中的作用域下的文档列表（保持向后兼容的入口）。
    public var documents: [IconDocument] { documentsList(for: selectedScope) }

    /// 指定作用域下的文档列表。
    public func documents(for scope: IconScope) -> [IconDocument] { documentsList(for: scope) }

    private func documentsList(for scope: IconScope) -> [IconDocument] {
        switch scope {
        case .project: return projectDocuments
        case .app: return appDocuments
        }
    }

    private func setDocumentsList(_ list: [IconDocument], for scope: IconScope) {
        switch scope {
        case .project: projectDocuments = list
        case .app: appDocuments = list
        }
    }

    public var selectedDocument: IconDocument? {
        let list = documentsList(for: selectedScope)
        if let selectedDocumentId, let match = list.first(where: { $0.id == selectedDocumentId }) {
            return match
        }
        return list.first
    }

    // MARK: - Paths

    /// APP 内存储路径字符串。
    public var appStoragePath: String { appStorageDirectory?.path ?? "" }

    /// 项目内存储路径字符串（无打开项目时为空）。
    public var projectStoragePath: String { projectStorageDirectory?.path ?? "" }

    /// 当前选中的作用域存储路径。
    public var storagePath: String { storagePath(for: selectedScope) }

    /// 指定作用域的存储路径（用于工具路由）。
    public func storagePath(for scope: IconScope) -> String {
        switch scope {
        case .project: projectStoragePath
        case .app: appStoragePath
        }
    }

    // MARK: - Configuration

    /// Binds the app-scope storage directory and reloads that scope.
    public func setAppStorage(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard self.appStorageDirectory != resolved else { return }
        self.appStorageDirectory = resolved
        if let resolved {
            try? fileManager.createDirectory(at: resolved, withIntermediateDirectories: true)
        }
        reloadScope(.app)
        refreshSelection()
    }

    /// Sets the project-scope storage directory and reloads that scope.
    public func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        let normalizedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathToStore = (normalizedPath?.isEmpty == false) ? normalizedPath : nil
        guard self.currentProjectPath != pathToStore else { return }
        self.currentProjectPath = pathToStore
        self.projectStorageDirectory = projectStorageDirectory?.standardizedFileURL
        if let projectStorageDirectory {
            try? fileManager.createDirectory(at: projectStorageDirectory, withIntermediateDirectories: true)
        }
        // 项目打开/关闭时，默认作用域跟随是否有项目。
        selectedScope = (pathToStore != nil) ? .project : .app
        reloadScope(.project)
        refreshSelection()
    }

    /// Reloads both scopes from disk and refreshes the current selection.
    public func reload() {
        lastError = nil
        reloadScope(.project)
        reloadScope(.app)
        refreshSelection()
    }

    /// Reloads one scope from disk.
    public func reloadScope(_ scope: IconScope) {
        let path = storagePath(for: scope)
        setDocumentsList(IconDocumentFileStore.loadAll(storagePath: path), for: scope)
    }

    /// 在某个作用域的数据变化后调用：按需刷新并切换选中。
    public func reload(scope: IconScope, selectDocumentId documentId: String? = nil) {
        reloadScope(scope)
        if let documentId {
            selectedScope = scope
            selectedDocumentId = documentId
        }
        refreshSelection()
    }

    private func refreshSelection() {
        let list = documentsList(for: selectedScope)
        if selectedDocumentId == nil || !list.contains(where: { $0.id == selectedDocumentId }) {
            selectedDocumentId = list.first?.id
        }
        clearHistory()
    }

    // MARK: - Create

    @discardableResult
    public func createDocument(
        title: String?,
        width: Double,
        height: Double,
        background: IconPaint,
        scope: IconScope
    ) -> IconDocument {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = IconDocumentSanitizer.sanitized(IconDocument(
            title: trimmedTitle?.isEmpty == false ? trimmedTitle! : "Untitled Icon",
            width: width,
            height: height,
            background: background
        ))
        insert(document, at: 0, scope: scope)
        selectedScope = scope
        selectedDocumentId = document.id
        clearHistory()
        persist(document, scope: scope)
        lastError = nil
        return document
    }

    @discardableResult
    public func createDocument(from preset: IconPreset, title: String? = nil, scope: IconScope) -> IconDocument {
        var document = IconDocumentSanitizer.sanitized(preset.makeDocument(title))
        document.createdAt = Date()
        document.updatedAt = document.createdAt
        insert(document, at: 0, scope: scope)
        selectedScope = scope
        selectedDocumentId = document.id
        clearHistory()
        persist(document, scope: scope)
        lastError = nil
        return document
    }

    // MARK: - Update

    @discardableResult
    public func updateDocument(
        id: String,
        scope: IconScope,
        _ update: (inout IconDocument) throws -> Void
    ) throws -> IconDocument {
        var list = documentsList(for: scope)
        guard let index = list.firstIndex(where: { $0.id == id }) else {
            throw IconDocumentStoreError.documentNotFound(id)
        }

        let previous = list[index]
        var next = previous
        try update(&next)
        next = IconDocumentSanitizer.sanitized(next)
        guard next != previous else {
            lastError = nil
            return previous
        }
        next.updatedAt = Date()
        list[index] = next
        setDocumentsList(list, for: scope)
        // 编辑只针对当前选中文档记录撤销历史，避免跨文档污染。
        if selectedScope == scope, selectedDocumentId == id {
            recordUndo(previous)
        }
        persist(next, scope: scope)
        lastError = nil
        return next
    }

    @discardableResult
    public func updateSelectedDocument(_ update: (inout IconDocument) throws -> Void) throws -> IconDocument {
        guard let selectedDocumentId else { throw IconDocumentStoreError.noSelectedDocument }
        return try updateDocument(id: selectedDocumentId, scope: selectedScope, update)
    }

    @discardableResult
    public func addLayer(_ layer: IconLayer, documentId: String, scope: IconScope) throws -> IconDocument {
        try updateDocument(id: documentId, scope: scope) { document in
            document.layers.append(layer)
        }
    }

    @discardableResult
    public func updateLayer(
        id layerId: String,
        documentId: String,
        scope: IconScope,
        _ update: (inout IconLayer) throws -> Void
    ) throws -> IconDocument {
        try updateDocument(id: documentId, scope: scope) { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }
            try update(&document.layers[index])
        }
    }

    @discardableResult
    public func renameLayer(id layerId: String, name: String) throws -> IconDocument {
        guard let selectedDocumentId else { throw IconDocumentStoreError.noSelectedDocument }
        return try updateLayer(id: layerId, documentId: selectedDocumentId, scope: selectedScope) { layer in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            layer.name = trimmed.isEmpty ? layer.name : trimmed
        }
    }

    @discardableResult
    public func duplicateLayer(id layerId: String) throws -> (document: IconDocument, layer: IconLayer) {
        var duplicatedLayer: IconLayer?
        let document = try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }
            var copy = document.layers[index]
            copy.id = UUID().uuidString
            copy.name = "\(copy.name) Copy"
            copy.transform.translateX += 32
            copy.transform.translateY += 32
            document.layers.insert(copy, at: index + 1)
            duplicatedLayer = copy
        }
        guard let duplicatedLayer else {
            throw IconDocumentStoreError.layerNotFound(layerId)
        }
        return (document, duplicatedLayer)
    }

    @discardableResult
    public func deleteLayer(id layerId: String) throws -> IconDocument {
        try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }
            document.layers.remove(at: index)
        }
    }

    @discardableResult
    public func moveLayer(id layerId: String, direction: LayerMoveDirection) throws -> IconDocument {
        try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }

            let targetIndex: Int
            switch direction {
            case .backward:
                targetIndex = max(0, index - 1)
            case .forward:
                targetIndex = min(document.layers.count - 1, index + 1)
            }

            guard targetIndex != index else { return }
            let layer = document.layers.remove(at: index)
            document.layers.insert(layer, at: targetIndex)
        }
    }

    @discardableResult
    public func replaceDocument(_ document: IconDocument, scope: IconScope) throws -> IconDocument {
        var replacement = IconDocumentSanitizer.sanitized(document)
        var list = documentsList(for: scope)
        if let index = list.firstIndex(where: { $0.id == replacement.id }) {
            let previous = list[index]
            replacement.updatedAt = Date()
            guard replacement != previous else {
                lastError = nil
                return previous
            }
            list[index] = replacement
            setDocumentsList(list, for: scope)
            if selectedScope == scope, selectedDocumentId == replacement.id {
                recordUndo(previous)
            }
            persist(replacement, scope: scope)
        } else {
            replacement.id = UUID().uuidString
            replacement.createdAt = Date()
            replacement.updatedAt = replacement.createdAt
            insert(replacement, at: 0, scope: scope)
            selectedScope = scope
            selectedDocumentId = replacement.id
            clearHistory()
            persist(replacement, scope: scope)
        }
        lastError = nil
        return replacement
    }

    @discardableResult
    public func importDocument(_ document: IconDocument, scope: IconScope) -> IconDocument {
        var imported = IconDocumentSanitizer.sanitized(document)
        imported.id = UUID().uuidString
        imported.createdAt = Date()
        imported.updatedAt = imported.createdAt
        insert(imported, at: 0, scope: scope)
        selectedScope = scope
        selectedDocumentId = imported.id
        clearHistory()
        persist(imported, scope: scope)
        lastError = nil
        return imported
    }

    public func undo() {
        guard let selectedDocumentId,
              let scope = scopeContaining(documentId: selectedDocumentId),
              var list = optionalList(for: scope),
              let index = list.firstIndex(where: { $0.id == selectedDocumentId }),
              let previous = undoStack.popLast()
        else { return }

        redoStack.append(list[index])
        list[index] = previous
        setDocumentsList(list, for: scope)
        persist(previous, scope: scope)
        updateHistoryFlags()
        lastError = nil
    }

    public func redo() {
        guard let selectedDocumentId,
              let scope = scopeContaining(documentId: selectedDocumentId),
              var list = optionalList(for: scope),
              let index = list.firstIndex(where: { $0.id == selectedDocumentId }),
              let next = redoStack.popLast()
        else { return }

        undoStack.append(list[index])
        list[index] = next
        setDocumentsList(list, for: scope)
        persist(next, scope: scope)
        updateHistoryFlags()
        lastError = nil
    }

    // MARK: - Selection

    /// 选中指定作用域内的文档。
    public func selectDocument(id: String, scope: IconScope) throws {
        guard documentsList(for: scope).contains(where: { $0.id == id }) else {
            throw IconDocumentStoreError.documentNotFound(id)
        }
        selectedScope = scope
        selectedDocumentId = id
        clearHistory()
    }

    /// 跨作用域查找并选中（回退：仅在两个列表中定位 id）。
    public func selectDocument(id: String) throws {
        if projectDocuments.contains(where: { $0.id == id }) {
            try selectDocument(id: id, scope: .project)
            return
        }
        if appDocuments.contains(where: { $0.id == id }) {
            try selectDocument(id: id, scope: .app)
            return
        }
        throw IconDocumentStoreError.documentNotFound(id)
    }

    /// Removes a document from the given scope and deletes its persisted file.
    public func deleteDocument(id: String, scope: IconScope) {
        var list = documentsList(for: scope)
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        let document = list[index]
        IconDocumentFileStore.delete(document, storagePath: storagePath(for: scope))
        list.remove(at: index)
        setDocumentsList(list, for: scope)

        if selectedScope == scope, selectedDocumentId == id {
            selectedDocumentId = list.isEmpty ? nil : list[min(index, list.count - 1)].id
            clearHistory()
        }
        lastError = nil
    }

    /// 跨作用域删除（回退用）。
    public func deleteDocument(id: String) {
        if let scope = scopeContaining(documentId: id) {
            deleteDocument(id: id, scope: scope)
        }
    }

    public func setExportURL(_ url: URL) {
        lastExportURL = url
        lastError = nil
    }

    public func setError(_ message: String) {
        lastError = message
    }

    public func resetForTests() {
        projectDocuments.removeAll()
        appDocuments.removeAll()
        selectedScope = .app
        selectedDocumentId = nil
        lastExportURL = nil
        lastError = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
        clearHistory()
    }

    // MARK: - Private helpers

    private func insert(_ document: IconDocument, at index: Int, scope: IconScope) {
        var list = documentsList(for: scope)
        list.insert(document, at: min(max(index, 0), list.count))
        setDocumentsList(list, for: scope)
    }

    private func optionalList(for scope: IconScope) -> [IconDocument]? {
        switch scope {
        case .project: return projectDocuments
        case .app: return appDocuments
        }
    }

    private func scopeContaining(documentId: String) -> IconScope? {
        if projectDocuments.contains(where: { $0.id == documentId }) { return .project }
        if appDocuments.contains(where: { $0.id == documentId }) { return .app }
        return nil
    }

    private func persist(_ document: IconDocument, scope: IconScope) {
        let path = storagePath(for: scope)
        guard !path.isEmpty else { return }
        do {
            try IconDocumentFileStore.save(document, storagePath: path)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func recordUndo(_ previous: IconDocument) {
        undoStack.append(previous)
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
        redoStack.removeAll()
        updateHistoryFlags()
    }

    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateHistoryFlags()
    }

    private func updateHistoryFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

public enum LayerMoveDirection: Equatable, Sendable {
    case backward
    case forward
}

public enum IconDocumentStoreError: LocalizedError, Equatable {
    case noSelectedDocument
    case documentNotFound(String)
    case layerNotFound(String)
    case invalidStorageScope

    public var errorDescription: String? {
        switch self {
        case .noSelectedDocument:
            return "No icon document is selected."
        case .documentNotFound(let id):
            return "Icon document not found: \(id)"
        case .layerNotFound(let id):
            return "Icon layer not found: \(id)"
        case .invalidStorageScope:
            return "The selected storage scope has no storage path."
        }
    }
}
