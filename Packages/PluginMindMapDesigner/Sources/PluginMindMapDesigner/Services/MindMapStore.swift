import Foundation

/// 思维导图状态单例。
///
/// 工具（agent tools）与画布视图共享同一实例：工具在 `MainActor.run` 内调用写方法，
/// `@Published` 变更驱动 `MindMapDesignerView` 自动重绘；每次写操作落盘。
@MainActor
public final class MindMapStore: ObservableObject {
    public static let shared = MindMapStore()

    /// 项目内（当前打开项目 `.lumi/mind-map`）思维导图列表。
    @Published public private(set) var projectMaps: [MindMap] = []

    /// APP 内（应用数据目录）思维导图列表。
    @Published public private(set) var appMaps: [MindMap] = []

    /// 当前选中的作用域。
    @Published public var selectedScope: MindMapScope = .app

    @Published public var selectedMapId: String?
    @Published public private(set) var lastError: String?

    private(set) var appStorageDirectory: URL?
    private(set) var projectStorageDirectory: URL?
    private(set) var currentProjectPath: String?
    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Lists

    /// 当前选中的作用域下的思维导图列表。
    public var maps: [MindMap] { list(for: selectedScope) }

    public func maps(for scope: MindMapScope) -> [MindMap] { list(for: scope) }

    private func list(for scope: MindMapScope) -> [MindMap] {
        switch scope {
        case .project: projectMaps
        case .app: appMaps
        }
    }

    private func setList(_ list: [MindMap], for scope: MindMapScope) {
        switch scope {
        case .project: projectMaps = list
        case .app: appMaps = list
        }
    }

    public var selectedMap: MindMap? {
        let list = self.list(for: selectedScope)
        if let selectedMapId, let match = list.first(where: { $0.id == selectedMapId }) {
            return match
        }
        return list.first
    }

    // MARK: - Paths

    public var appStoragePath: String { appStorageDirectory?.path ?? "" }
    public var projectStoragePath: String { projectStorageDirectory?.path ?? "" }
    public var storagePath: String { storagePath(for: selectedScope) }

    public func storagePath(for scope: MindMapScope) -> String {
        switch scope {
        case .project: projectStoragePath
        case .app: appStoragePath
        }
    }

    // MARK: - Configuration

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

    public func reload() {
        lastError = nil
        reloadScope(.project)
        reloadScope(.app)
        refreshSelection()
    }

    public func reloadScope(_ scope: MindMapScope) {
        let path = storagePath(for: scope)
        setList(MindMapFileStore.loadAll(storagePath: path), for: scope)
    }

    /// 在某个作用域的数据变化后调用：按需刷新并切换选中。
    public func reload(scope: MindMapScope, selectMapId mapId: String? = nil) {
        reloadScope(scope)
        if let mapId {
            selectedScope = scope
            selectedMapId = mapId
        }
        refreshSelection()
    }

    private func refreshSelection() {
        let list = self.list(for: selectedScope)
        if selectedMapId == nil || !list.contains(where: { $0.id == selectedMapId }) {
            selectedMapId = list.first?.id
        }
    }

    // MARK: - Create

    @discardableResult
    public func createMindMap(
        title: String?,
        rootText: String,
        direction: MindMapLayoutDirection,
        scope: MindMapScope
    ) -> MindMap {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle! : rootText
        let root = MindMapNode(parentId: nil, text: rootText)
        let map = MindMap(title: finalTitle, nodes: [root], layoutDirection: direction)
        insert(map, at: 0, scope: scope)
        selectedScope = scope
        selectedMapId = map.id
        persist(map, scope: scope)
        lastError = nil
        return map
    }

    // MARK: - Node Mutations

    /// 给指定父节点批量添加子节点，返回更新后的思维导图与新建节点列表。
    @discardableResult
    public func addChildNodes(
        mapId: String,
        parentId: String,
        texts: [String],
        color: String?,
        scope: MindMapScope
    ) throws -> (MindMap, [MindMapNode]) {
        var created: [MindMapNode] = []
        let map = try updateMap(id: mapId, scope: scope) { mm in
            guard mm.node(id: parentId) != nil else {
                throw MindMapStoreError.nodeNotFound(parentId)
            }
            for text in texts {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let node = MindMapNode(parentId: parentId, text: trimmed, color: color)
                mm.nodes.append(node)
                created.append(node)
            }
            // 父节点若已折叠，展开以便看到新增子节点。
            if let index = mm.nodes.firstIndex(where: { $0.id == parentId }), mm.nodes[index].collapsed {
                mm.nodes[index].collapsed = false
            }
        }
        return (map, created)
    }

    /// 添加单个兄弟节点（插在 `siblingId` 之后），用于手动编辑。
    @discardableResult
    public func addSiblingNode(mapId: String, siblingId: String, text: String, scope: MindMapScope) throws -> (MindMap, MindMapNode?) {
        var created: MindMapNode?
        let map = try updateMap(id: mapId, scope: scope) { mm in
            guard let sibling = mm.node(id: siblingId), let parentId = sibling.parentId else {
                // 根节点没有兄弟：退化为加子节点。
                return
            }
            let node = MindMapNode(parentId: parentId, text: text)
            if let index = mm.nodes.firstIndex(where: { $0.id == siblingId }) {
                mm.nodes.insert(node, at: index + 1)
            } else {
                mm.nodes.append(node)
            }
            created = node
        }
        return (map, created)
    }

    @discardableResult
    public func updateNode(
        mapId: String,
        nodeId: String,
        scope: MindMapScope,
        text: String?,
        note: String?,
        color: String?,
        collapsed: Bool?
    ) throws -> MindMap {
        try updateMap(id: mapId, scope: scope) { mm in
            guard let index = mm.nodes.firstIndex(where: { $0.id == nodeId }) else {
                throw MindMapStoreError.nodeNotFound(nodeId)
            }
            if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                mm.nodes[index].text = text
            }
            if let note { mm.nodes[index].note = note }
            if let color { mm.nodes[index].color = color }
            if let collapsed { mm.nodes[index].collapsed = collapsed }
        }
    }

    /// 删除节点及其整个子树（根节点不可删除）。
    @discardableResult
    public func deleteNode(mapId: String, nodeId: String, scope: MindMapScope) throws -> MindMap {
        try updateMap(id: mapId, scope: scope) { mm in
            guard mm.node(id: nodeId) != nil else {
                throw MindMapStoreError.nodeNotFound(nodeId)
            }
            guard mm.root?.id != nodeId else {
                throw MindMapStoreError.cannotDeleteRoot
            }
            let ids = mm.descendantIds(of: nodeId)
            let toRemove = ids.union([nodeId])
            mm.nodes.removeAll { toRemove.contains($0.id) }
        }
    }

    /// 把节点（含子树）重新挂到新的父节点下。
    @discardableResult
    public func moveNode(mapId: String, nodeId: String, toParentId: String, scope: MindMapScope) throws -> MindMap {
        try updateMap(id: mapId, scope: scope) { mm in
            guard let index = mm.nodes.firstIndex(where: { $0.id == nodeId }) else {
                throw MindMapStoreError.nodeNotFound(nodeId)
            }
            guard mm.node(id: toParentId) != nil else {
                throw MindMapStoreError.nodeNotFound(toParentId)
            }
            guard nodeId != toParentId, !mm.wouldCreateCycle(nodeId: nodeId, newParentId: toParentId) else {
                throw MindMapStoreError.invalidMove
            }
            mm.nodes[index].parentId = toParentId
        }
    }

    // MARK: - Whole-map Mutations

    @discardableResult
    public func replaceMindMap(_ map: MindMap, scope: MindMapScope) throws -> MindMap {
        var list = self.list(for: scope)
        var replacement = map
        if let index = list.firstIndex(where: { $0.id == replacement.id }) {
            replacement.updatedAt = Date()
            list[index] = replacement
            setList(list, for: scope)
            persist(replacement, scope: scope)
        } else {
            replacement.id = UUID().uuidString
            replacement.createdAt = Date()
            replacement.updatedAt = replacement.createdAt
            insert(replacement, at: 0, scope: scope)
            selectedScope = scope
            selectedMapId = replacement.id
            persist(replacement, scope: scope)
        }
        lastError = nil
        return replacement
    }

    @discardableResult
    public func importFromMarkdown(
        markdown: String,
        title: String?,
        direction: MindMapLayoutDirection,
        scope: MindMapScope
    ) -> MindMap {
        var map = MindMapMarkdownCodec.decode(markdown: markdown, title: title, direction: direction)
        map.id = UUID().uuidString
        map.createdAt = Date()
        map.updatedAt = map.createdAt
        insert(map, at: 0, scope: scope)
        selectedScope = scope
        selectedMapId = map.id
        persist(map, scope: scope)
        lastError = nil
        return map
    }

    // MARK: - Selection & Delete

    public func selectMindMap(id: String, scope: MindMapScope) throws {
        guard self.list(for: scope).contains(where: { $0.id == id }) else {
            throw MindMapStoreError.mapNotFound(id)
        }
        selectedScope = scope
        selectedMapId = id
    }

    public func selectMindMap(id: String) throws {
        if projectMaps.contains(where: { $0.id == id }) {
            try selectMindMap(id: id, scope: .project)
            return
        }
        if appMaps.contains(where: { $0.id == id }) {
            try selectMindMap(id: id, scope: .app)
            return
        }
        throw MindMapStoreError.mapNotFound(id)
    }

    public func deleteMindMap(id: String, scope: MindMapScope) {
        var list = self.list(for: scope)
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        let map = list[index]
        MindMapFileStore.delete(map, storagePath: storagePath(for: scope))
        list.remove(at: index)
        setList(list, for: scope)

        if selectedScope == scope, selectedMapId == id {
            selectedMapId = list.isEmpty ? nil : list[min(index, list.count - 1)].id
        }
        lastError = nil
    }

    public func setError(_ message: String) {
        lastError = message
    }

    public func resetForTests() {
        projectMaps.removeAll()
        appMaps.removeAll()
        selectedScope = .app
        selectedMapId = nil
        lastError = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
    }

    // MARK: - Private Helpers

    @discardableResult
    private func updateMap(id: String, scope: MindMapScope, _ update: (inout MindMap) throws -> Void) throws -> MindMap {
        var list = self.list(for: scope)
        guard let index = list.firstIndex(where: { $0.id == id }) else {
            throw MindMapStoreError.mapNotFound(id)
        }
        let previous = list[index]
        var next = previous
        try update(&next)
        guard next != previous else {
            lastError = nil
            return previous
        }
        next.updatedAt = Date()
        list[index] = next
        setList(list, for: scope)
        persist(next, scope: scope)
        lastError = nil
        return next
    }

    private func insert(_ map: MindMap, at index: Int, scope: MindMapScope) {
        var list = self.list(for: scope)
        list.insert(map, at: min(max(index, 0), list.count))
        setList(list, for: scope)
    }

    private func persist(_ map: MindMap, scope: MindMapScope) {
        let path = storagePath(for: scope)
        guard !path.isEmpty else { return }
        do {
            try MindMapFileStore.save(map, storagePath: path)
        } catch {
            lastError = error.localizedDescription
        }
    }
}

public enum MindMapStoreError: LocalizedError, Equatable {
    case noSelectedMap
    case mapNotFound(String)
    case nodeNotFound(String)
    case cannotDeleteRoot
    case invalidMove

    public var errorDescription: String? {
        switch self {
        case .noSelectedMap:
            return "No mind map is selected."
        case .mapNotFound(let id):
            return "Mind map not found: \(id)"
        case .nodeNotFound(let id):
            return "Mind map node not found: \(id)"
        case .cannotDeleteRoot:
            return "The root node cannot be deleted."
        case .invalidMove:
            return "This move would create a cycle and is not allowed."
        }
    }
}
