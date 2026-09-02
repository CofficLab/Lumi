@preconcurrency import ObjectiveC
import AppKit
import KitSuperLog
import os

/// Spotlight 文件搜索结果条目
public struct LauncherFileItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool

    public init(id: String, name: String, path: String, isDirectory: Bool) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }
}

/// 全局文件搜索服务（基于 Spotlight / NSMetadataQuery）
///
/// 每次搜索创建一次性 query，等待首批结果通知（带超时降级），
/// 避免与 QuickFileSearchPlugin 的项目内索引产生耦合。
@MainActor
public final class FileSearchService: NSObject, ObservableObject, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = false

    public static let shared = FileSearchService()

    // MARK: - State

    /// 当前查询词
    @Published public var searchQuery: String = ""

    /// 搜索结果
    @Published public private(set) var results: [LauncherFileItem] = []

    /// 是否正在搜索
    @Published public private(set) var isSearching = false

    private var activeQuery: NSMetadataQuery?
    private var searchTask: Task<Void, Never>?
    private var generation = 0

    /// 单次查询超时（秒）——Spotlight 未命中时降级返回空
    private let queryTimeout: TimeInterval = 1.5
    /// 结果上限
    private let resultLimit = 15

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Search

    /// 提交搜索（内部带 200ms 防抖）
    public func search(_ query: String) {
        searchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            cancelSearch()
            return
        }

        generation += 1
        let currentGeneration = generation
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            await self.runSpotlightQuery(trimmed, generation: currentGeneration)
        }
    }

    /// 取消进行中的搜索并清空结果
    public func cancelSearch() {
        generation += 1
        searchTask?.cancel()
        stopActiveQuery()
        results = []
        isSearching = false
    }

    /// 执行一次 Spotlight 查询，等待首批通知或超时
    private func runSpotlightQuery(_ query: String, generation currentGeneration: Int) async {
        stopActiveQuery()
        isSearching = true
        results = []

        let metadataQuery = NSMetadataQuery()
        // 名称包含匹配（大小写/音调不敏感）
        metadataQuery.predicate = NSPredicate(
            format: "kMDItemDisplayName LIKE[cd] %@",
            "*" + query + "*"
        )
        metadataQuery.searchScopes = [NSMetadataQueryLocalComputerScope]
        metadataQuery.operationQueue = .main
        metadataQuery.start()
        activeQuery = metadataQuery

        // 首批 gathering 完成 / 超时 / Task 取消，三者任一先到即恢复
        let timeout = queryTimeout
        let gatheringObserver = SpotlightGatheringObserver(query: metadataQuery, timeout: timeout)
        for await _ in gatheringObserver.stream {
            break
        }
        gatheringObserver.finish()

        metadataQuery.stop()
        activeQuery = nil

        // 查询已被新的搜索取代
        guard !Task.isCancelled, currentGeneration == generation else { return }
        results = Self.collect(from: metadataQuery, limit: resultLimit)
        isSearching = false
    }

    private func stopActiveQuery() {
        activeQuery?.stop()
        activeQuery = nil
    }

    /// 从 query 中收集结果（同步）
    nonisolated static func collect(from query: NSMetadataQuery, limit: Int) -> [LauncherFileItem] {
        var items: [LauncherFileItem] = []
        let count = min(query.resultCount, limit * 2)
        guard count > 0 else { return [] }

        for index in 0..<count {
            guard let item = query.result(at: index) as? NSMetadataItem else { continue }
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let name = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
                ?? (path as NSString).lastPathComponent
            let folder = (item.value(forAttribute: NSMetadataItemContentTypeKey) as? String) == "public.folder"
                || (item.value(forAttribute: NSMetadataItemKindKey) as? String) == "Folder"
            items.append(
                LauncherFileItem(
                    id: path,
                    name: name,
                    path: path,
                    isDirectory: folder
                )
            )
            if items.count >= limit { break }
        }
        return items
    }

    // MARK: - Open

    /// 打开文件（默认应用）
    public func openFile(_ item: LauncherFileItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
    }

    /// 在 Finder 中显示
    public func revealInFinder(_ item: LauncherFileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }
}
