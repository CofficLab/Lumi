import Foundation
import MagicKit

/// RAG 核心服务
///
/// - 负责初始化本地数据库
/// - 负责项目索引（全量/增量）
/// - 负责查询检索并返回相关片段
actor RAGService: SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let verbose: Bool = false

    private static let pluginName = "RAGPlugin"
    private static let ensureThrottleSeconds: TimeInterval = 20
    private static let staleAfterSeconds: TimeInterval = 300
    private nonisolated static let indexingRegistry = RAGIndexingRegistry()

    /// 线程安全的初始化状态容器
    private final class InitializationState: @unchecked Sendable {
        private let lock = NSLock()
        private var _isInitialized: Bool = false

        var isInitialized: Bool {
            get { lock.withLock { _isInitialized } }
            set { lock.withLock { _isInitialized = newValue } }
        }
    }

    private let initializationState = InitializationState()
    private var store: RAGSQLiteStore?
    private var indexer: RAGIndexer?
    private var retriever: RAGRetriever?
    private var embeddingProvider: RAGEmbeddingProvider?
    private var lastEnsureAttemptByProject: [String: Date] = [:]

    /// 正在后台索引的项目路径集合
    private var indexingProjects: Set<String> = []

    /// 非阻塞地检查服务是否已初始化
    nonisolated var isInitialized: Bool {
        initializationState.isInitialized
    }

    init() {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🦞 RAG 服务已创建")
        }
    }

    // MARK: - Lifecycle

    func initialize() async throws {
        guard !isInitialized else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)♻️ initialize: 已初始化，跳过")
            }
            return
        }

        let start = CFAbsoluteTimeGetCurrent()

        let dbURL = AppConfig.getPluginDBFolderURL(pluginName: Self.pluginName)
            .appendingPathComponent("rag.sqlite")

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📦 initialize: 开始初始化")
            AppLogger.core.info("\(Self.t)   DB 路径：\(dbURL.path)")
        }

        let store = try RAGSQLiteStore(dbURL: dbURL)
        try store.migrate()
        let embeddingProvider = RAGEmbeddingFactory.makeProvider()
        try store.configureVectorBackend(embeddingDimension: embeddingProvider.dimension)

        self.store = store
        self.indexer = RAGIndexer(
            store: store,
            embeddingProvider: embeddingProvider
        )
        self.retriever = RAGRetriever(store: store)
        self.embeddingProvider = embeddingProvider
        initializationState.isInitialized = true

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if Self.verbose {
            AppLogger.core.info("\(Self.t)⏱️ initialize 耗时：\(RAGUtils.formatDuration(duration))")
        }
    }

    // MARK: - Indexing

    /// 确保指定项目已建立可用索引（不存在则全量，存在则增量）
    func ensureIndexed(projectPath: String, force: Bool = false) async throws {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let indexer else { throw RAGError.internalStateCorrupted }
        guard let store else { throw RAGError.internalStateCorrupted }
        guard let embeddingProvider else { throw RAGError.internalStateCorrupted }

        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { throw RAGError.invalidProjectPath }
        Self.indexingRegistry.start(projectPath: normalized)
        defer { Self.indexingRegistry.finish(projectPath: normalized) }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🧱 ensureIndexed 开始 force=\(force) project=\(normalized)")
        }

        let indexState = try store.fetchProjectIndexState(projectPath: normalized)
        let modelMismatch = indexState.map {
            $0.embeddingModel != embeddingProvider.modelIdentifierWithVersion
                || $0.embeddingDimension != embeddingProvider.dimension
        } ?? false
        if let indexState {
            if Self.verbose {
                AppLogger.core.info(
                    "\(Self.t)📌 当前索引状态 embedding=\(indexState.embeddingModel) dim=\(indexState.embeddingDimension) chunks=\(indexState.chunkCount)"
                )
            }
        } else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📌 当前项目无索引状态")
            }
        }
        if Self.verbose {
            AppLogger.core.info(
                "\(Self.t)🧠 目标 embedding=\(embeddingProvider.modelIdentifierWithVersion) dim=\(embeddingProvider.dimension) modelMismatch=\(modelMismatch)"
            )
        }

        if force || modelMismatch {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)♻️ 执行全量重建索引")
            }
            let stats = try indexer.rebuildProjectIndex(at: normalized)
            if Self.verbose {
                AppLogger.core.info(
                    "\(Self.t)✅ 全量重建完成 scanned=\(stats.scannedFiles) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) chunks=\(stats.chunkCount)"
                )
            }
            return
        }

        if !force {
            let now = Date()
            if let lastAttempt = lastEnsureAttemptByProject[normalized],
               now.timeIntervalSince(lastAttempt) < Self.ensureThrottleSeconds {
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)⏱️ 跳过：节流窗口内")
                }
                return
            }
            if let state = indexState,
               !isIndexStateStale(state, now: now) {
                lastEnsureAttemptByProject[normalized] = now
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)🟢 跳过：索引未过期")
                }
                return
            }
            lastEnsureAttemptByProject[normalized] = now
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🔁 执行增量索引")
        }
        let stats = try indexer.indexProjectIncrementally(at: normalized)
        if Self.verbose {
            AppLogger.core.info(
                "\(Self.t)✅ 增量索引完成 scanned=\(stats.scannedFiles) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) chunks=\(stats.chunkCount)"
            )
        }
    }

    /// 检查项目是否需要索引（快速检查，不执行实际索引）
    /// - Returns: true 表示需要索引，false 表示索引已经是最新
    func checkNeedsIndex(projectPath: String) async throws -> Bool {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let store else { throw RAGError.internalStateCorrupted }
        guard let embeddingProvider else { throw RAGError.internalStateCorrupted }

        let start = CFAbsoluteTimeGetCurrent()

        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { throw RAGError.invalidProjectPath }

        let indexState = try store.fetchProjectIndexState(projectPath: normalized)

        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        if Self.verbose {
            AppLogger.core.info("\(Self.t)⏱️ checkNeedsIndex 耗时：\(RAGUtils.formatDuration(duration))")
        }

        // 无索引状态，需要索引
        guard let state = indexState else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 checkNeedsIndex: 无索引状态，需要索引")
            }
            return true
        }

        // 检查模型是否匹配
        let modelMismatch = state.embeddingModel != embeddingProvider.modelIdentifierWithVersion
            || state.embeddingDimension != embeddingProvider.dimension
        if modelMismatch {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 checkNeedsIndex: 模型不匹配，需要索引")
            }
            return true
        }

        // 检查索引是否过期
        let now = Date()
        let isStale = isIndexStateStale(state, now: now)
        if isStale {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 checkNeedsIndex: 索引已过期，需要索引")
            }
            return true
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📊 checkNeedsIndex: 索引是最新的，无需索引")
        }
        return false
    }

    /// 在后台启动索引任务，不阻塞调用方
    /// - Parameters:
    ///   - projectPath: 项目路径
    ///   - force: 是否强制重建
    func ensureIndexedBackground(projectPath: String, force: Bool = false) async {
        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { return }

        // 防止重复启动后台索引
        guard !indexingProjects.contains(normalized) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🔄 后台索引已在进行中，跳过: \(normalized)")
            }
            return
        }
        guard !Self.indexingRegistry.contains(projectPath: normalized) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🔄 索引已在进行中（全局标记），跳过: \(normalized)")
            }
            return
        }

        indexingProjects.insert(normalized)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🚀 启动后台索引任务: \(normalized)")
        }

        // 在后台 Task 中执行索引
        Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                try await self.ensureIndexed(projectPath: projectPath, force: force)
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)✅ 后台索引任务完成: \(normalized)")
                }
            } catch {
                if Self.verbose {
                    AppLogger.core.error("\(Self.t)❌ 后台索引任务失败: \(normalized) - \(error)")
                }
            }

            // 移除索引标记
            await self.removeIndexingProject(normalized)
        }
    }

    private func removeIndexingProject(_ projectPath: String) {
        indexingProjects.remove(projectPath)
    }

    /// 兼容旧接口：执行一次全量重建
    func indexProject(at path: String) async throws {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let indexer else { throw RAGError.internalStateCorrupted }

        let normalized = normalizeProjectPath(path)
        guard !normalized.isEmpty else { throw RAGError.invalidProjectPath }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🔁 执行全量重建索引")
        }
        _ = try indexer.rebuildProjectIndex(at: normalized)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 全量重建完成")
        }
    }

    // MARK: - Retrieval

    /// 兼容旧接口：在全部项目范围检索
    func retrieve(query: String, topK: Int = 3) async throws -> RAGResponse {
        try await retrieve(query: query, projectPath: nil, topK: topK)
    }

    /// 检索相关文档（可限定项目）
    func retrieve(query: String, projectPath: String?, topK: Int = 3) async throws -> RAGResponse {
        let start = CFAbsoluteTimeGetCurrent()

        guard isInitialized else { throw RAGError.notInitialized }
        guard let retriever else { throw RAGError.internalStateCorrupted }
        guard let embeddingProvider else { throw RAGError.internalStateCorrupted }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return RAGResponse(query: query, results: []) }

        let normalizedProjectPath = projectPath.map(normalizeProjectPath)

        // ⏱️ 向量化耗时
        let embedStart = CFAbsoluteTimeGetCurrent()
        let queryEmbedding = try embeddingProvider.embed(trimmed)
        let embedDuration = (CFAbsoluteTimeGetCurrent() - embedStart) * 1000

        if Self.verbose {
            AppLogger.core.info("\(Self.t)⏱️ embed 耗时：\(RAGUtils.formatDuration(embedDuration))")
        }

        // ⏱️ 检索耗时
        let retrieveStart = CFAbsoluteTimeGetCurrent()
        let results = try retriever.retrieve(
            queryEmbedding: queryEmbedding,
            query: trimmed,
            projectPath: normalizedProjectPath,
            topK: max(topK, 1)
        )
        let retrieveDuration = (CFAbsoluteTimeGetCurrent() - retrieveStart) * 1000

        if Self.verbose {
            AppLogger.core.info("\(Self.t)⏱️ retriever.retrieve 耗时：\(RAGUtils.formatDuration(retrieveDuration))，结果数：\(results.count)")
        }

        let totalDuration = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if Self.verbose {
            AppLogger.core.info("\(Self.t)⏱️ retrieve 总耗时：\(RAGUtils.formatDuration(totalDuration))")
        }

        // ⚠️ 性能预警
        if Self.verbose, totalDuration > 300 {
            AppLogger.core.warning("\(Self.t)⚠️ retrieve 总耗时过长：\(RAGUtils.formatDuration(totalDuration)) (>300ms) [embed=\(RAGUtils.formatDuration(embedDuration)), retriever=\(RAGUtils.formatDuration(retrieveDuration))]")
        }

        return RAGResponse(query: query, results: results)
    }

    func getIndexStatus(projectPath: String) async throws -> RAGIndexStatus? {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let store else { throw RAGError.internalStateCorrupted }

        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { throw RAGError.invalidProjectPath }
        guard let state = try store.fetchProjectIndexState(projectPath: normalized) else { return nil }

        let lastIndexed = Date(timeIntervalSince1970: state.lastIndexedAt)
        return RAGIndexStatus(
            projectPath: state.projectPath,
            lastIndexedAt: lastIndexed,
            fileCount: state.fileCount,
            chunkCount: state.chunkCount,
            embeddingModel: state.embeddingModel,
            embeddingDimension: state.embeddingDimension,
            isStale: isIndexStateStale(state, now: Date())
        )
    }

    func getRuntimeInfo() async throws -> RAGRuntimeInfo {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let store else { throw RAGError.internalStateCorrupted }
        return store.runtimeInfo
    }

    private func normalizeProjectPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// 非阻塞地查询项目是否正在索引（不进入 actor 队列）
    nonisolated static func isIndexing(projectPath: String) -> Bool {
        let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        return indexingRegistry.contains(projectPath: normalized)
    }

    /// 非阻塞地查询是否存在任意项目正在索引（不进入 actor 队列）
    nonisolated static func isAnyIndexing() -> Bool {
        indexingRegistry.hasAnyIndexing()
    }

    private func isIndexStateStale(_ state: RAGProjectIndexState, now: Date) -> Bool {
        let indexedAt = Date(timeIntervalSince1970: state.lastIndexedAt)
        return now.timeIntervalSince(indexedAt) > Self.staleAfterSeconds
    }
}
