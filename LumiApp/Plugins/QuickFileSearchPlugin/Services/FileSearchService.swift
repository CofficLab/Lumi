import AppKit
import MagicKit
import Foundation
import SwiftUI
import os

/// 文件搜索服务
///
/// 负责文件索引、搜索算法和结果排序
@MainActor
final class FileSearchService: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    static let shared = FileSearchService()

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

    // MARK: - Initialization

    private init() {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ FileSearchService 初始化完成")
        }
    }

    // MARK: - Public Methods

    /// 更新当前项目并重新索引
    func updateProject(path: String) {
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
    func clearIndex() {
        currentProjectPath = ""
        indexStore.clear()
        searchResults = []
        searchQuery = ""
    }

    /// 选择文件并更新 ProjectVM
    func selectFile(_ result: FileResult) {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)📄 选择文件: \(result.relativePath)")
        }

        // 发送通知，FileTreeSyncOverlay 会更新 projectVM
        NotificationCenter.postSyncSelectedFile(path: result.path)

        // 清空搜索查询
        searchQuery = ""
    }

    // MARK: - Private Methods

    /// 重建文件索引
    private func rebuildIndex(for path: String) {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let startTime = Date()
            let files = FileSearchHelpers.scanProjectFiles(at: path)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isLoading = false
                self.indexStore.update(files)

                let duration = Date().timeIntervalSince(startTime)
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)📦 索引完成: \(files.count) 个文件，耗时 \(String(format: "%.2f", duration))s")
                }
            }
        }
    }

    // MARK: - Search Query Handler

    /// 监听搜索查询变化
    func onSearchQueryChanged() {
        // 取消之前的搜索任务
        searchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespaces)

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
        let startTime = Date()
        let lowercaseQuery = query.lowercased()

        // 在访问 self.indexStore 之前先捕获文件列表
        let files = indexStore.files

        // 在后台线程执行搜索
        let results = FileSearchHelpers.searchInFiles(files, query: lowercaseQuery)

        // 检查任务是否被取消
        guard !Task.isCancelled else { return }

        await MainActor.run { [weak self] in
            guard let self else { return }
            self.searchResults = results

            let duration = Date().timeIntervalSince(startTime)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🔍 搜索完成: '\(query)' -> \(results.count) 个结果，耗时 \(String(format: "%.2f", duration * 1000))ms")
            }
        }
    }
}

/// 文件搜索辅助工具
///
/// nonisolated 类，用于在非 MainActor 上下文中执行搜索相关操作
enum FileSearchHelpers {
    /// 扫描项目文件
    static func scanProjectFiles(at path: String) -> [FileResult] {
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
            let relativePath = url.path.replacingOccurrences(of: path + "/", with: "")
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

    /// 检查是否应该跳过该路径
    static func shouldSkipPath(_ url: URL) -> Bool {
        let path = url.path.lowercased()

        // 跳过常见的构建产物和依赖目录
        let skipPatterns = [
            "/build/",
            "/.build/",
            "/deriveddata/",
            "/.deriveddata/",
            "/node_modules/",
            "/.git/",
            "/.svn/",
            "/.hg/",
            "/.vscode/",
            "/.idea/",
            "/.vs/",
            "/pod/",
            "/pods/",
            "/carthage/",
            "/vendor/",
            "/.cache/",
            "/.next/",
            "/.nuxt/",
            "/dist/",
            "/out/",
            "/bin/",
            "/obj/",
            "/.xcodeenv/",
        ]

        return skipPatterns.contains { path.contains($0) }
    }

    /// 在文件列表中搜索
    static func searchInFiles(_ files: [FileResult], query: String) -> [FileResult] {
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
            .map(\.0)

        // 限制最多返回 100 条结果
        return Array(sorted.prefix(100))
    }

    /// 模糊匹配算法
    /// 检查 text 是否按顺序包含 query 的所有字符
    static func fuzzyMatch(_ text: String, query: String) -> Bool {
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
