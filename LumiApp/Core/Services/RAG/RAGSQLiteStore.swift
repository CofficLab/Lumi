import CryptoKit
import Foundation
import SQLite3

final class RAGSQLiteStore {
    private var db: OpaquePointer?
    private let dbURL: URL
    private(set) var runtimeInfo: RAGRuntimeInfo = RAGRuntimeInfo(
        vectorBackend: .swiftCosine,
        sqliteVecPath: nil,
        note: "初始化中"
    )

    init(dbURL: URL) throws {
        self.dbURL = dbURL
        try open()
        self.runtimeInfo = try detectRuntimeInfo()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS rag_files (
            project_path TEXT NOT NULL,
            file_path TEXT NOT NULL,
            mtime REAL NOT NULL,
            content_hash TEXT NOT NULL,
            updated_at REAL NOT NULL,
            PRIMARY KEY(project_path, file_path)
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS rag_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_path TEXT NOT NULL,
            file_path TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            content TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            mtime REAL NOT NULL,
            embedding BLOB NOT NULL,
            dimension INTEGER NOT NULL,
            created_at REAL NOT NULL
        );
        """)

        try execute("CREATE INDEX IF NOT EXISTS idx_rag_chunks_project ON rag_chunks(project_path);")
        try execute("CREATE INDEX IF NOT EXISTS idx_rag_chunks_file ON rag_chunks(project_path, file_path);")

        try execute("""
        CREATE TABLE IF NOT EXISTS rag_index_state (
            project_path TEXT PRIMARY KEY,
            last_indexed_at REAL NOT NULL,
            file_count INTEGER NOT NULL,
            chunk_count INTEGER NOT NULL,
            embedding_model TEXT NOT NULL,
            embedding_dimension INTEGER NOT NULL
        );
        """)
    }

    func fetchIndexedFileStates(projectPath: String) throws -> [String: RAGIndexedFileState] {
        let sql = """
        SELECT file_path, mtime, content_hash
        FROM rag_files
        WHERE project_path = ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare fetchIndexedFileStates failed")
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)

        var states: [String: RAGIndexedFileState] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let filePathPtr = sqlite3_column_text(statement, 0),
                let hashPtr = sqlite3_column_text(statement, 2)
            else { continue }
            let filePath = String(cString: filePathPtr)
            let mtime = sqlite3_column_double(statement, 1)
            let contentHash = String(cString: hashPtr)
            states[filePath] = RAGIndexedFileState(
                filePath: filePath,
                modifiedTime: mtime,
                contentHash: contentHash
            )
        }
        return states
    }

    func replaceFileChunks(
        projectPath: String,
        filePath: String,
        modifiedTime: Double,
        contentHash: String,
        chunks: [RAGChunk],
        embeddingDimension: Int
    ) throws {
        try execute("BEGIN TRANSACTION;")
        do {
            try deleteChunks(projectPath: projectPath, filePath: filePath)

            let insertSQL = """
            INSERT INTO rag_chunks
            (project_path, file_path, chunk_index, content, content_hash, mtime, embedding, dimension, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var insertStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else {
                throw dbError("prepare replaceFileChunks insert failed")
            }
            defer { sqlite3_finalize(insertStmt) }

            let createdAt = Date().timeIntervalSince1970
            for chunk in chunks {
                sqlite3_reset(insertStmt)
                sqlite3_clear_bindings(insertStmt)

                sqlite3_bind_text(insertStmt, 1, (projectPath as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 2, (filePath as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(insertStmt, 3, Int64(chunk.index))
                sqlite3_bind_text(insertStmt, 4, (chunk.content as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 5, (contentHash as NSString).utf8String, -1, nil)
                sqlite3_bind_double(insertStmt, 6, modifiedTime)

                let embedding = RAGEmbedding.embed(chunk.content, dimension: embeddingDimension)
                let embeddingData = embedding.toData()
                embeddingData.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(insertStmt, 7, buffer.baseAddress, Int32(embeddingData.count), nil)
                }
                sqlite3_bind_int64(insertStmt, 8, Int64(embeddingDimension))
                sqlite3_bind_double(insertStmt, 9, createdAt)

                guard sqlite3_step(insertStmt) == SQLITE_DONE else {
                    throw dbError("insert rag_chunks failed")
                }
            }

            try upsertFileState(
                projectPath: projectPath,
                filePath: filePath,
                modifiedTime: modifiedTime,
                contentHash: contentHash
            )

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func deleteFileState(projectPath: String, filePath: String) throws {
        let sql = "DELETE FROM rag_files WHERE project_path = ? AND file_path = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare deleteFileState failed")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (filePath as NSString).utf8String, -1, nil)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw dbError("deleteFileState failed")
        }
    }

    func upsertFileStateOnly(
        projectPath: String,
        filePath: String,
        modifiedTime: Double,
        contentHash: String
    ) throws {
        try upsertFileState(
            projectPath: projectPath,
            filePath: filePath,
            modifiedTime: modifiedTime,
            contentHash: contentHash
        )
    }

    func deleteChunks(projectPath: String, filePath: String) throws {
        let sql = "DELETE FROM rag_chunks WHERE project_path = ? AND file_path = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare deleteChunks failed")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (filePath as NSString).utf8String, -1, nil)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw dbError("deleteChunks failed")
        }
    }

    func upsertProjectIndexState(
        projectPath: String,
        fileCount: Int,
        chunkCount: Int,
        embeddingModel: String,
        embeddingDimension: Int
    ) throws {
        let sql = """
        INSERT INTO rag_index_state
        (project_path, last_indexed_at, file_count, chunk_count, embedding_model, embedding_dimension)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(project_path) DO UPDATE SET
          last_indexed_at = excluded.last_indexed_at,
          file_count = excluded.file_count,
          chunk_count = excluded.chunk_count,
          embedding_model = excluded.embedding_model,
          embedding_dimension = excluded.embedding_dimension;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare upsertProjectIndexState failed")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        sqlite3_bind_int64(statement, 3, Int64(fileCount))
        sqlite3_bind_int64(statement, 4, Int64(chunkCount))
        sqlite3_bind_text(statement, 5, (embeddingModel as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(statement, 6, Int64(embeddingDimension))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw dbError("upsertProjectIndexState failed")
        }
    }

    func loadChunks(projectPath: String?, limit: Int? = nil) throws -> [RAGStoredChunk] {
        var sql = "SELECT content, file_path, embedding FROM rag_chunks"
        if projectPath != nil {
            sql += " WHERE project_path = ?"
        }
        sql += " ORDER BY id DESC"
        if let limit {
            sql += " LIMIT \(max(limit, 1))"
        }
        sql += ";"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare loadChunks failed")
        }
        defer { sqlite3_finalize(statement) }

        if let projectPath {
            sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)
        }

        var chunks: [RAGStoredChunk] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let contentPtr = sqlite3_column_text(statement, 0),
                let filePathPtr = sqlite3_column_text(statement, 1),
                let embeddingPtr = sqlite3_column_blob(statement, 2)
            else { continue }

            let content = String(cString: contentPtr)
            let filePath = String(cString: filePathPtr)
            let bytes = Int(sqlite3_column_bytes(statement, 2))
            let data = Data(bytes: embeddingPtr, count: bytes)
            let embedding = [Float](data: data)

            chunks.append(RAGStoredChunk(content: content, filePath: filePath, embedding: embedding))
        }

        return chunks
    }

    func loadCandidateChunks(
        projectPath: String?,
        queryTerms: [String],
        lexicalLimit: Int = 2500,
        fallbackLimit: Int = 6500
    ) throws -> [RAGStoredChunk] {
        let terms = Array(Set(queryTerms.filter { !$0.isEmpty }))
        guard !terms.isEmpty else {
            return try loadChunks(projectPath: projectPath, limit: fallbackLimit)
        }

        var params: [String] = []
        var whereParts: [String] = []
        if let projectPath {
            whereParts.append("project_path = ?")
            params.append(projectPath)
        }

        var termConds: [String] = []
        for _ in terms {
            termConds.append("LOWER(content) LIKE ?")
            termConds.append("LOWER(file_path) LIKE ?")
        }
        whereParts.append("(" + termConds.joined(separator: " OR ") + ")")
        for term in terms {
            let pattern = "%\(term.lowercased())%"
            params.append(pattern)
            params.append(pattern)
        }

        let sql = """
        SELECT content, file_path, embedding
        FROM rag_chunks
        WHERE \(whereParts.joined(separator: " AND "))
        ORDER BY id DESC
        LIMIT \(max(lexicalLimit, 1));
        """
        let lexical = try queryChunks(sql: sql, params: params)
        if lexical.count >= lexicalLimit {
            return lexical
        }

        let fallback = try loadChunks(projectPath: projectPath, limit: fallbackLimit)
        var merged: [RAGStoredChunk] = []
        var seen = Set<String>()
        merged.reserveCapacity(lexical.count + fallback.count)

        for item in lexical + fallback {
            let key = item.filePath + "::" + String(item.content.prefix(80))
            if seen.insert(key).inserted {
                merged.append(item)
            }
        }
        return merged
    }

    func fetchProjectIndexState(projectPath: String) throws -> RAGProjectIndexState? {
        let sql = """
        SELECT project_path, last_indexed_at, file_count, chunk_count, embedding_model, embedding_dimension
        FROM rag_index_state
        WHERE project_path = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare fetchProjectIndexState failed")
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard
            let pathPtr = sqlite3_column_text(statement, 0),
            let modelPtr = sqlite3_column_text(statement, 4)
        else {
            return nil
        }

        return RAGProjectIndexState(
            projectPath: String(cString: pathPtr),
            lastIndexedAt: sqlite3_column_double(statement, 1),
            fileCount: Int(sqlite3_column_int64(statement, 2)),
            chunkCount: Int(sqlite3_column_int64(statement, 3)),
            embeddingModel: String(cString: modelPtr),
            embeddingDimension: Int(sqlite3_column_int64(statement, 5))
        )
    }

    func countProjectFiles(projectPath: String) throws -> Int {
        try querySingleInt(
            sql: "SELECT COUNT(*) FROM rag_files WHERE project_path = ?;",
            param: projectPath
        )
    }

    func countProjectChunks(projectPath: String) throws -> Int {
        try querySingleInt(
            sql: "SELECT COUNT(*) FROM rag_chunks WHERE project_path = ?;",
            param: projectPath
        )
    }

    static func contentHash(_ content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private

    private func open() throws {
        try FileManager.default.createDirectory(
            at: dbURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var pointer: OpaquePointer?
        if sqlite3_open(dbURL.path, &pointer) != SQLITE_OK {
            let message = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close(pointer)
            throw RAGError.dbError(message)
        }
        db = pointer
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "execute failed"
            sqlite3_free(errorMessage)
            throw RAGError.dbError(message)
        }
    }

    private func upsertFileState(
        projectPath: String,
        filePath: String,
        modifiedTime: Double,
        contentHash: String
    ) throws {
        let sql = """
        INSERT INTO rag_files
        (project_path, file_path, mtime, content_hash, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(project_path, file_path) DO UPDATE SET
          mtime = excluded.mtime,
          content_hash = excluded.content_hash,
          updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare upsertFileState failed")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (projectPath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (filePath as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, modifiedTime)
        sqlite3_bind_text(statement, 4, (contentHash as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw dbError("upsertFileState failed")
        }
    }

    private func querySingleInt(sql: String, param: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare querySingleInt failed")
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (param as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func dbError(_ message: String) -> RAGError {
        let sqliteMessage = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        return .dbError("\(message): \(sqliteMessage)")
    }

    private func queryChunks(sql: String, params: [String]) throws -> [RAGStoredChunk] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw dbError("prepare queryChunks failed")
        }
        defer { sqlite3_finalize(statement) }

        for (idx, param) in params.enumerated() {
            sqlite3_bind_text(statement, Int32(idx + 1), (param as NSString).utf8String, -1, nil)
        }

        var rows: [RAGStoredChunk] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let contentPtr = sqlite3_column_text(statement, 0),
                let filePathPtr = sqlite3_column_text(statement, 1),
                let embeddingPtr = sqlite3_column_blob(statement, 2)
            else { continue }

            let content = String(cString: contentPtr)
            let filePath = String(cString: filePathPtr)
            let bytes = Int(sqlite3_column_bytes(statement, 2))
            let data = Data(bytes: embeddingPtr, count: bytes)
            let embedding = [Float](data: data)
            rows.append(RAGStoredChunk(content: content, filePath: filePath, embedding: embedding))
        }
        return rows
    }

    private func detectRuntimeInfo() throws -> RAGRuntimeInfo {
        guard db != nil else {
            return RAGRuntimeInfo(vectorBackend: .swiftCosine, sqliteVecPath: nil, note: "数据库未就绪")
        }

        let envPath = ProcessInfo.processInfo.environment["RAG_SQLITE_VEC_PATH"]
        var candidates: [String] = []
        if let envPath, !envPath.isEmpty {
            candidates.append(envPath)
        }
        let dir = dbURL.deletingLastPathComponent().path
        candidates.append(contentsOf: [
            "\(dir)/sqlite-vec0.dylib",
            "\(dir)/sqlite-vec.dylib",
            "/opt/homebrew/lib/sqlite-vec0.dylib",
            "/opt/homebrew/lib/sqlite-vec.dylib",
            "/usr/local/lib/sqlite-vec0.dylib",
            "/usr/local/lib/sqlite-vec.dylib"
        ])

        // NOTE:
        // Apple 平台上通过 Swift 的 SQLite3 模块不一定暴露扩展加载 API
        // （如 sqlite3_enable_load_extension / sqlite3_load_extension）。
        // 为避免编译不兼容，这里仅做“文件存在性探测”，运行时继续使用 Swift 侧余弦检索。
        let fm = FileManager.default
        if let path = candidates.first(where: { fm.fileExists(atPath: $0) }) {
            return RAGRuntimeInfo(
                vectorBackend: .swiftCosine,
                sqliteVecPath: path,
                note: "检测到 sqlite-vec 动态库，但当前构建未启用 SQLite 扩展加载接口"
            )
        }

        return RAGRuntimeInfo(vectorBackend: .swiftCosine, sqliteVecPath: nil, note: "未检测到 sqlite-vec 动态库")
    }
}

private extension Array where Element == Float {
    func toData() -> Data {
        guard !isEmpty else { return Data() }
        return withUnsafeBufferPointer { ptr in
            Data(bytes: ptr.baseAddress!, count: ptr.count * MemoryLayout<Float>.size)
        }
    }
}

private extension Array where Element == Float {
    init(data: Data) {
        self = data.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }
}
