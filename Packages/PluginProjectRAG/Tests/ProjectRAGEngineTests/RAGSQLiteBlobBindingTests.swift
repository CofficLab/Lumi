import CSQLite
import Foundation
import Testing

@testable import ProjectRAGEngine

/// 回归 #1111：`sqlite3_step` 在 `withUnsafeBytes` 闭包外执行，blob 必须
/// 使用 `SQLITE_TRANSIENT` 让 SQLite 在 bind 返回前复制，不能依赖闭包外
/// 已失效的 buffer 指针。
@Suite struct RAGSQLiteBlobBindingTests {
    @Test("SQLite 在 bind 返回前复制 blob")
    func sqliteCopiesBlobBeforeBindReturns() throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        #expect(sqlite3_exec(db, "CREATE TABLE t(v BLOB);", nil, nil, nil) == SQLITE_OK)

        var insert: OpaquePointer?
        #expect(
            sqlite3_prepare_v2(db, "INSERT INTO t(v) VALUES (?);", -1, &insert, nil)
                == SQLITE_OK
        )
        defer { sqlite3_finalize(insert) }

        let original = (0..<256).map { UInt8(truncatingIfNeeded: $0) }
        let raw = UnsafeMutableRawBufferPointer.allocate(
            byteCount: original.count,
            alignment: 1
        )
        defer { raw.deallocate() }
        original.withUnsafeBytes { raw.copyBytes(from: $0) }

        let bindStatus = RAGSQLiteBlobBinding.bind(
            insert,
            index: 1,
            bytes: UnsafeRawBufferPointer(raw)
        )
        #expect(bindStatus == SQLITE_OK)

        // bind 返回后覆写源缓冲区：TRANSIENT 已复制旧值，STATIC 会读到新值。
        memset(raw.baseAddress, 0xFF, raw.count)

        #expect(sqlite3_step(insert) == SQLITE_DONE)

        var select: OpaquePointer?
        #expect(
            sqlite3_prepare_v2(db, "SELECT v FROM t;", -1, &select, nil) == SQLITE_OK
        )
        defer { sqlite3_finalize(select) }
        #expect(sqlite3_step(select) == SQLITE_ROW)

        let byteCount = Int(sqlite3_column_bytes(select, 0))
        let stored = Array(
            UnsafeRawBufferPointer(
                start: sqlite3_column_blob(select, 0),
                count: byteCount
            )
        )
        #expect(byteCount == original.count)
        #expect(stored == original)
    }

    @Test("源缓冲区释放后仍能读回完整向量")
    func storedEmbeddingSurvivesSourceBufferRelease() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-rag-blob-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try RAGSQLiteStore(dbURL: root.appendingPathComponent("rag.sqlite"))
        try store.migrate()
        store.runtimeInfo = RAGRuntimeInfo(vectorBackend: .swiftCosine, note: "test")

        let projectPath = "/tmp/lumi-rag-blob-project"
        let embedding = (0..<64).map { Float($0) * 0.25 - 3 }
        try store.replaceFileChunks(
            projectPath: projectPath,
            filePath: "Sources/Blob.swift",
            modifiedTime: 1_700_000_000,
            contentHash: "blob-hash",
            chunks: [RAGChunk(index: 0, content: "let value = 1")],
            embeddings: [embedding],
            embeddingDimension: embedding.count
        )

        // 尽量复用可能已释放的缓冲区，放大悬垂指针的影响。
        var churn: [Data] = []
        for index in 0..<128 {
            churn.append(Data(repeating: UInt8(truncatingIfNeeded: index), count: 4096))
        }

        let loaded = try store.loadChunks(projectPath: projectPath)
        #expect(loaded.count == 1)
        #expect(loaded.first?.embedding == embedding)
        #expect(churn.count == 128)
    }
}
