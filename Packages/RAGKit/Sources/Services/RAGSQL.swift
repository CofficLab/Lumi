import Foundation

/// RAGSQLiteStore 使用的 SQL 常量
enum RAGSQL {
    // MARK: - Table Creation

    static let createFilesTable = """
    CREATE TABLE IF NOT EXISTS rag_files (
        project_path TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mtime REAL NOT NULL,
        content_hash TEXT NOT NULL,
        updated_at REAL NOT NULL,
        PRIMARY KEY(project_path, file_path)
    );
    """

    static let createChunksTable = """
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
    """

    static let createIndexStateTable = """
    CREATE TABLE IF NOT EXISTS rag_index_state (
        project_path TEXT PRIMARY KEY,
        last_indexed_at REAL NOT NULL,
        file_count INTEGER NOT NULL,
        chunk_count INTEGER NOT NULL,
        embedding_model TEXT NOT NULL,
        embedding_dimension INTEGER NOT NULL
    );
    """

    // MARK: - Indexes

    static let createChunksProjectIndex = "CREATE INDEX IF NOT EXISTS idx_rag_chunks_project ON rag_chunks(project_path);"
    static let createChunksFileIndex = "CREATE INDEX IF NOT EXISTS idx_rag_chunks_file ON rag_chunks(project_path, file_path);"

    // MARK: - File State Queries

    static let fetchFileStates = """
    SELECT file_path, mtime, content_hash
    FROM rag_files
    WHERE project_path = ?;
    """

    static let upsertFileState = """
    INSERT INTO rag_files
    (project_path, file_path, mtime, content_hash, updated_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(project_path, file_path) DO UPDATE SET
      mtime = excluded.mtime,
      content_hash = excluded.content_hash,
      updated_at = excluded.updated_at;
    """

    static let deleteFileState = "DELETE FROM rag_files WHERE project_path = ? AND file_path = ?;"

    // MARK: - Chunk Queries

    static let insertChunk = """
    INSERT INTO rag_chunks
    (project_path, file_path, chunk_index, content, content_hash, mtime, embedding, dimension, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let deleteChunksByFile = "DELETE FROM rag_chunks WHERE project_path = ? AND file_path = ?;"
    static let fetchChunkIDsByFile = "SELECT id FROM rag_chunks WHERE project_path = ? AND file_path = ?;"

    static let selectChunksBase = """
    SELECT id, content, file_path, embedding
    FROM rag_chunks
    """

    // MARK: - Index State Queries

    static let upsertProjectIndexState = """
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

    static let fetchProjectIndexState = """
    SELECT project_path, last_indexed_at, file_count, chunk_count, embedding_model, embedding_dimension
    FROM rag_index_state
    WHERE project_path = ?
    LIMIT 1;
    """

    // MARK: - Count Queries

    static let countProjectFiles = "SELECT COUNT(*) FROM rag_files WHERE project_path = ?;"
    static let countProjectChunks = "SELECT COUNT(*) FROM rag_chunks WHERE project_path = ?;"

    // MARK: - Vector Index Queries

    static let dropVectorTable = "DROP TABLE IF EXISTS rag_vec_chunks;"

    static func createVectorTable(dimension: Int) -> String {
        "CREATE VIRTUAL TABLE rag_vec_chunks USING vec0(embedding float[\(dimension)]);"
    }

    static let selectVectorNearest = """
    SELECT rowid, distance
    FROM rag_vec_chunks
    WHERE embedding MATCH ? AND k = ?;
    """

    static let upsertVectorIndex = "INSERT OR REPLACE INTO rag_vec_chunks(rowid, embedding) VALUES (?, ?);"
    static let rebuildVectorFromChunks = "SELECT id, embedding FROM rag_chunks;"
}
