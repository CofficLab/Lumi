import AppKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os
import os.signpost

private enum QuickFileSearchSignpost {
    private static let log = OSLog(subsystem: "com.coffic.lumi", category: "plugin.quick-file-search.performance")

    @discardableResult
    static func begin(_ name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    static func end(_ name: StaticString, _ id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }
}

private enum QuickFileSearchLog {
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quick-file-search")
}

/// 文件搜索服务
///
/// 负责文件索引、搜索算法和结果排序
@MainActor
public final class FileSearchService: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    public static let shared = FileSearchService()

    // MARK: - Published Properties

    /// 搜索查询文本
    @Published var searchQuery: String = ""

    /// 搜索结果列表
    @Published private(set) var searchResults: [FileResult] = []

    /// 是否正在加载
    @Published private(set) var isLoading: Bool = false

    /// 当前项目路径
    @Published private(set) var currentProjectPath: String = ""

    // MARK: - Private Properties

    private var indexStore = FileIndexStore(projectPath: "")
    private var searchTask: Task<Void, Never>?
    private var indexingProjectPath: String?

    // MARK: - Initialization

    private init() {
        if Self.verbose {
            QuickFileSearchLog.logger.info("\(Self.t)\(Self.emoji) FileSearchService 初始化完成")
        }
    }

    // MARK: - Public Methods

    /// 更新当前项目并重新索引
    public func updateProject(path: String) {
        guard !path.isEmpty else {
            clearIndex()
            return
        }

        guard path != currentProjectPath else {
            // 即使路径相同，也检查是否需要重新索引
            if indexStore.needsReindex() {
                rebuildIndex(for: path)
            }
            return
        }

        currentProjectPath = path
        indexStore = FileIndexStore(projectPath: path)
        rebuildIndex(for: path)
    }

    /// 清空索引
    public func clearIndex() {
        currentProjectPath = ""
        indexStore.clear()
        searchResults = []
        searchQuery = ""
    }

    /// 选择文件并更新项目状态
    public func selectFile(_ result: FileResult, windowId: UUID? = nil) {
        if Self.verbose {
            QuickFileSearchLog.logger.info("\(Self.t)📄 选择文件: \(result.relativePath)")
        }

        QuickFileSearchBridge.selectFileHandler?(result.path, windowId)

        // 清空搜索查询
        searchQuery = ""
    }

    public func quickOpenResults(
        matching query: String,
        projectPath: String,
        limit: Int = 40
    ) -> [FileResult] {
        let normalizedLimit = max(0, limit)
        guard normalizedLimit > 0 else { return [] }

        let normalizedProjectPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedProjectPath.isEmpty, !normalizedQuery.isEmpty else { return [] }

        if currentProjectPath != normalizedProjectPath {
            currentProjectPath = normalizedProjectPath
            indexStore = FileIndexStore(projectPath: normalizedProjectPath)
        }

        if indexStore.files.isEmpty || indexStore.needsReindex() {
            rebuildIndex(for: normalizedProjectPath)
        }

        return Array(
            FileSearchHelpers
                .searchInFiles(indexStore.files, query: normalizedQuery)
                .prefix(normalizedLimit)
        )
    }

    // MARK: - Private Methods

    /// 重建文件索引
    private func rebuildIndex(for path: String) {
        guard indexingProjectPath != path else { return }
        indexingProjectPath = path
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let signpostID = QuickFileSearchSignpost.begin("QuickFileSearch.rebuildIndex")
            defer { QuickFileSearchSignpost.end("QuickFileSearch.rebuildIndex", signpostID) }

            let startTime = Date()
            let files = FileSearchHelpers.scanProjectFiles(at: path)

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.indexingProjectPath == path else { return }
                self.indexingProjectPath = nil
                self.isLoading = false
                guard self.currentProjectPath == path else { return }
                self.indexStore.update(files)
                if Self.shouldRefreshSearchAfterIndexing(query: self.searchQuery) {
                    self.onSearchQueryChanged()
                }

                let duration = Date().timeIntervalSince(startTime)
                if Self.verbose {
                    QuickFileSearchLog.logger.info("\(Self.t)📦 索引完成: \(files.count) 个文件，耗时 \(String(format: "%.2f", duration))s")
                }
            }
        }
    }

    // MARK: - Search Query Handler

    /// 监听搜索查询变化
    public func onSearchQueryChanged() {
        // 取消之前的搜索任务
        searchTask?.cancel()

        let query = Self.normalizedQuery(searchQuery)

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        // 创建新的搜索任务
        searchTask = Task { [weak self] in
            await self?.performSearch(query: query)
        }
    }

    /// 执行搜索
    private func performSearch(query: String) async {
        let signpostID = QuickFileSearchSignpost.begin("QuickFileSearch.performSearch")
        defer { QuickFileSearchSignpost.end("QuickFileSearch.performSearch", signpostID) }

        let startTime = Date()
        let lowercaseQuery = query.lowercased()

        // 在访问 self.indexStore 之前先捕获文件列表
        let files = indexStore.files

        let results = await Task.detached(priority: .userInitiated) {
            FileSearchHelpers.searchInFiles(files, query: lowercaseQuery)
        }.value

        await MainActor.run { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard Self.shouldApplySearchResults(currentQuery: self.searchQuery, completedQuery: query) else { return }
            self.searchResults = results

            let duration = Date().timeIntervalSince(startTime)
            if Self.verbose {
                QuickFileSearchLog.logger.info("\(Self.t)🔍 搜索完成: '\(query)' -> \(results.count) 个结果，耗时 \(String(format: "%.2f", duration * 1000))ms")
            }
        }
    }

    nonisolated static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated static func shouldApplySearchResults(currentQuery: String, completedQuery: String) -> Bool {
        normalizedQuery(currentQuery) == normalizedQuery(completedQuery)
    }

    nonisolated static func shouldRefreshSearchAfterIndexing(query: String) -> Bool {
        !normalizedQuery(query).isEmpty
    }
}

/// 文件搜索辅助工具
///
/// nonisolated 类，用于在非 MainActor 上下文中执行搜索相关操作
public enum FileSearchHelpers {
    /// 扫描项目文件
    public static func scanProjectFiles(at path: String) -> [FileResult] {
        let rootURL = URL(fileURLWithPath: path)
        var results: [FileResult] = []

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            // 跳过常见的忽略目录
            if shouldSkipPath(url) {
                enumerator.skipDescendants()
                continue
            }

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            // 对于目录，只显示第一级，不递归索引
            if isDirectory {
                // 只添加项目根目录下的直接子目录
                if url.deletingLastPathComponent().path == rootURL.path {
                    let relativePath = url.lastPathComponent
                    results.append(FileResult(
                        name: url.lastPathComponent,
                        path: url.path,
                        relativePath: relativePath,
                        isDirectory: true,
                        score: 0
                    ))
                }
                continue
            }

            // 添加文件
            let relativePath = relativePath(for: url, rootPath: path)
            results.append(FileResult(
                name: url.lastPathComponent,
                path: url.path,
                relativePath: relativePath,
                isDirectory: false,
                score: 0
            ))

            // 限制最大文件数（避免过大的项目导致性能问题）
            if results.count >= 10000 {
                break
            }
        }

        return results
    }

    static func relativePath(for fileURL: URL, rootPath: String) -> String {
        let filePath = normalizedPath(fileURL.path)
        let rootPath = normalizedPath(rootPath)

        guard filePath != rootPath else { return fileURL.lastPathComponent }

        let rootPrefix = rootPath == "/" ? "/" : rootPath + "/"
        guard filePath.hasPrefix(rootPrefix) else {
            return fileURL.lastPathComponent
        }

        return String(filePath.dropFirst(rootPrefix.count))
    }

    private static func normalizedPath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        guard standardized.count > 1 else { return standardized }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }

    /// 检查是否应该跳过该路径
    public static func shouldSkipPath(_ url: URL) -> Bool {
        let skippedComponents: Set<String> = [
            "build",
            ".build",
            "deriveddata",
            ".deriveddata",
            "node_modules",
            ".git",
            ".svn",
            ".hg",
            ".vscode",
            ".idea",
            ".vs",
            "pod",
            "pods",
            "carthage",
            "vendor",
            ".cache",
            ".next",
            ".nuxt",
            "dist",
            "out",
            "bin",
            "obj",
            ".xcodeenv",
        ]

        return url.standardizedFileURL.pathComponents
            .map { $0.lowercased() }
            .contains { skippedComponents.contains($0) }
    }

    /// 在文件列表中搜索
    public static func searchInFiles(_ files: [FileResult], query: String) -> [FileResult] {
        guard !query.isEmpty else { return [] }

        var scoredResults: [(FileResult, Int)] = []

        for file in files {
            var score = 0
            let name = file.name.lowercased()
            let relativePath = file.relativePath.lowercased()

            // 1. 精确前缀匹配（最高优先级）
            if name.hasPrefix(query) {
                score = 100
            }
            // 2. 包含匹配（文件名）
            else if name.contains(query) {
                score = 80
            }
            // 3. 路径匹配
            else if relativePath.contains(query) {
                score = 60
            }
            // 4. 模糊匹配
            else if fuzzyMatch(name, query: query) {
                score = 40
            }
            // 5. 路径模糊匹配
            else if fuzzyMatch(relativePath, query: query) {
                score = 20
            }

            if score > 0 {
                scoredResults.append((file, score))
            }
        }

        // 按分数排序，分数相同时按文件名字母序
        let sorted = scoredResults
            .sorted { a, b in
                if a.1 != b.1 {
                    return a.1 > b.1
                }
                return a.0.name < b.0.name
            }
            .map { file, score in
                FileResult(
                    name: file.name,
                    path: file.path,
                    relativePath: file.relativePath,
                    isDirectory: file.isDirectory,
                    score: score
                )
            }

        // 限制最多返回 100 条结果
        return Array(sorted.prefix(100))
    }

    /// 模糊匹配算法
    /// 检查 text 是否按顺序包含 query 的所有字符
    public static func fuzzyMatch(_ text: String, query: String) -> Bool {
        guard !query.isEmpty else { return false }

        var queryIndex = query.startIndex

        for char in text {
            if char == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
                if queryIndex == query.endIndex {
                    return true
                }
            }
        }

        return false
    }
}
