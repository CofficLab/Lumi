import Foundation

/// RAG 数据持久层抽象
/// 用于解耦 RAGRetriever/RAGIndexer 对 RAGSQLiteStore 的直接依赖
protocol RAGStore: Sendable {
    func fetchIndexedFileStates(projectPath: String) throws -> [String: RAGIndexedFileState]
    func replaceFileChunks(
        projectPath: String,
        filePath: String,
        modifiedTime: Double,
        contentHash: String,
        chunks: [RAGChunk],
        embeddings: [[Float]],
        embeddingDimension: Int
    ) throws
    func deleteChunks(projectPath: String, filePath: String) throws
    func deleteFileState(projectPath: String, filePath: String) throws
    func upsertFileStateOnly(
        projectPath: String,
        filePath: String,
        modifiedTime: Double,
        contentHash: String
    ) throws
    func upsertProjectIndexState(
        projectPath: String,
        fileCount: Int,
        chunkCount: Int,
        embeddingModel: String,
        embeddingDimension: Int
    ) throws
    func loadChunks(projectPath: String?, limit: Int?) throws -> [RAGStoredChunk]
    func loadCandidateChunks(
        projectPath: String?,
        queryTerms: [String],
        lexicalLimit: Int,
        fallbackLimit: Int
    ) throws -> [RAGStoredChunk]
    func loadChunksByIDs(_ chunkIDs: [Int64], projectPath: String?) throws -> [RAGStoredChunk]
    func fetchProjectIndexState(projectPath: String) throws -> RAGProjectIndexState?
    func countProjectFiles(projectPath: String) throws -> Int
    func countProjectChunks(projectPath: String) throws -> Int
    func searchNearestVectors(queryEmbedding: [Float], limit: Int) throws -> [RAGVectorMatch]?
}

/// 确认 RAGSQLiteStore 满足 RAGStore 协议
extension RAGSQLiteStore: RAGStore {}
