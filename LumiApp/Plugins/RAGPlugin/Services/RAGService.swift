import Foundation
import MagicKit

/// RAG 核心服务
///
/// - 负责初始化本地数据库
/// - 负责项目索引（全量/增量）
/// - 负责查询检索并返回相关片段
actor RAGService: SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let verbose = false

    private static let pluginName = "RAGPlugin"
    private static let ensureThrottleSeconds: TimeInterval = 20
    private static let staleAfterSeconds: TimeInterval = 300

    private(set) var isInitialized: Bool = false
    private var store: RAGSQLiteStore?
    private var indexer: RAGIndexer?
    private var retriever: RAGRetriever?
    private var embeddingProvider: RAGEmbeddingProvider?
    private var lastEnsureAttemptByProject: [String: Date] = [:]

    init() {
        AppLogger.core.info("\(Self.t)🦞 RAG 服务已创建")
    }

    // MARK: - Lifecycle

    func initialize() async throws {
        guard !isInitialized else { return }

        let dbURL = AppConfig.getPluginDBFolderURL(pluginName: Self.pluginName)
            .appendingPathComponent("rag.sqlite")

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
        self.isInitialized = true

        AppLogger.core.info(
            "\(Self.t)✅ RAG 服务初始化完成，DB: \(dbURL.path), embedding=\(embeddingProvider.modelIdentifierWithVersion), dim=\(embeddingProvider.dimension), backend=\(store.runtimeInfo.vectorBackend.rawValue)"
        )
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
        AppLogger.core.info("\(Self.t)🧱 ensureIndexed 开始 force=\(force) project=\(normalized)")

        let indexState = try store.fetchProjectIndexState(projectPath: normalized)
        let modelMismatch = indexState.map {
            $0.embeddingModel != embeddingProvider.modelIdentifierWithVersion
                || $0.embeddingDimension != embeddingProvider.dimension
        } ?? false
        if let indexState {
            AppLogger.core.info(
                "\(Self.t)📌 当前索引状态 embedding=\(indexState.embeddingModel) dim=\(indexState.embeddingDimension) chunks=\(indexState.chunkCount)"
            )
        } else {
            AppLogger.core.info("\(Self.t)📌 当前项目无索引状态")
        }
        AppLogger.core.info(
            "\(Self.t)🧠 目标 embedding=\(embeddingProvider.modelIdentifierWithVersion) dim=\(embeddingProvider.dimension) modelMismatch=\(modelMismatch)"
        )

        if force || modelMismatch {
            AppLogger.core.info("\(Self.t)♻️ 执行全量重建索引")
            let stats = try indexer.rebuildProjectIndex(at: normalized)
            AppLogger.core.info(
                "\(Self.t)✅ 全量重建完成 scanned=\(stats.scannedFiles) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) chunks=\(stats.chunkCount)"
            )
            return
        }

        if !force {
            let now = Date()
            if let lastAttempt = lastEnsureAttemptByProject[normalized],
               now.timeIntervalSince(lastAttempt) < Self.ensureThrottleSeconds {
                AppLogger.core.info("\(Self.t)⏱️ 跳过：节流窗口内")
                return
            }
            if let state = indexState,
               !isIndexStateStale(state, now: now) {
                lastEnsureAttemptByProject[normalized] = now
                AppLogger.core.info("\(Self.t)🟢 跳过：索引未过期")
                return
            }
            lastEnsureAttemptByProject[normalized] = now
        }

        AppLogger.core.info("\(Self.t)🔁 执行增量索引")
        let stats = try indexer.indexProjectIncrementally(at: normalized)
        AppLogger.core.info(
            "\(Self.t)✅ 增量索引完成 scanned=\(stats.scannedFiles) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) chunks=\(stats.chunkCount)"
        )
    }

    /// 兼容旧接口：执行一次全量重建
    func indexProject(at path: String) async throws {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let indexer else { throw RAGError.internalStateCorrupted }

        let normalized = normalizeProjectPath(path)
        guard !normalized.isEmpty else { throw RAGError.invalidProjectPath }

        _ = try indexer.rebuildProjectIndex(at: normalized)
    }

    // MARK: - Retrieval

    /// 兼容旧接口：在全部项目范围检索
    func retrieve(query: String, topK: Int = 3) async throws -> RAGResponse {
        try await retrieve(query: query, projectPath: nil, topK: topK)
    }

    /// 检索相关文档（可限定项目）
    func retrieve(query: String, projectPath: String?, topK: Int = 3) async throws -> RAGResponse {
        guard isInitialized else { throw RAGError.notInitialized }
        guard let retriever else { throw RAGError.internalStateCorrupted }
        guard let embeddingProvider else { throw RAGError.internalStateCorrupted }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return RAGResponse(query: query, results: []) }

        let normalizedProjectPath = projectPath.map(normalizeProjectPath)
        let queryEmbedding = try embeddingProvider.embed(trimmed)
        let results = try retriever.retrieve(
            queryEmbedding: queryEmbedding,
            query: trimmed,
            projectPath: normalizedProjectPath,
            topK: max(topK, 1)
        )

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

    private func isIndexStateStale(_ state: RAGProjectIndexState, now: Date) -> Bool {
        let indexedAt = Date(timeIntervalSince1970: state.lastIndexedAt)
        return now.timeIntervalSince(indexedAt) > Self.staleAfterSeconds
    }
}

// MARK: - Errors

enum RAGError: LocalizedError {
    case notInitialized
    case invalidProjectPath
    case internalStateCorrupted
    case dbError(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "RAG 服务未初始化"
        case .invalidProjectPath:
            return "无效的项目路径"
        case .internalStateCorrupted:
            return "RAG 内部状态异常"
        case let .dbError(message):
            return "RAG 数据库错误：\(message)"
        }
    }
}
