import Foundation
import Testing
@testable import ProjectRAGEngine

/// Regression coverage for issue #926: the idle scheduler and the project
/// lifecycle hook can index different projects at the same time, and both go
/// through the single `RAGSQLiteStore` connection.
@Suite struct RAGSQLiteStoreConcurrencyTests {

    @Test func concurrentWritersOnOneConnectionDoNotCollide() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-concurrent-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let store = try RAGSQLiteStore(dbURL: dbURL)
        try store.migrate()
        store.runtimeInfo = RAGRuntimeInfo(vectorBackend: .swiftCosine)

        let writerCount = 8
        let chunksPerFile = 200
        let chunks = (0..<chunksPerFile).map { index in
            RAGChunk(index: index, content: "func feature\(index)() {}")
        }
        let embeddings = chunks.map { _ in [Float](repeating: 0.25, count: 32) }

        // Every writer is released at the same instant so their
        // `BEGIN TRANSACTION` statements overlap unless the store serializes
        // them. Without that serialization one of them fails with
        // "cannot start a transaction within a transaction".
        let ready = DispatchSemaphore(value: 0)
        let start = DispatchSemaphore(value: 0)
        let finished = DispatchGroup()
        let failures = ErrorCollector()

        for index in 0..<writerCount {
            let projectPath = "/project-\(index)"
            DispatchQueue.global(qos: .userInitiated).async {
                finished.enter()
                defer { finished.leave() }
                ready.signal()
                start.wait()
                do {
                    try store.replaceFileChunks(
                        projectPath: projectPath,
                        filePath: "\(projectPath)/Feature.swift",
                        modifiedTime: 1,
                        contentHash: "hash-\(index)",
                        chunks: chunks,
                        embeddings: embeddings,
                        embeddingDimension: 32
                    )
                } catch {
                    failures.append(error)
                }
            }
        }

        for _ in 0..<writerCount {
            ready.wait()
        }
        for _ in 0..<writerCount {
            start.signal()
        }
        let waitResult = finished.wait(timeout: .now() + 60)
        #expect(waitResult == .success)
        #expect(failures.snapshot.isEmpty, "concurrent indexing failures: \(failures.snapshot)")

        // A failed transaction would also leave its project without a file
        // state, so verify every project committed the full chunk set.
        for index in 0..<writerCount {
            let projectPath = "/project-\(index)"
            let states = try store.fetchIndexedFileStates(projectPath: projectPath)
            #expect(states.count == 1)
            let stored = try store.loadChunks(projectPath: projectPath)
            #expect(stored.count == chunksPerFile)
        }
    }
}

private final class ErrorCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [Error] = []

    func append(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        errors.append(error)
    }

    var snapshot: [String] {
        lock.lock()
        defer { lock.unlock() }
        return errors.map(\.localizedDescription)
    }
}
