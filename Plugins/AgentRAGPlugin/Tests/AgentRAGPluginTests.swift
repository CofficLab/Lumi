import Foundation
import LumiCoreKit
import Testing
@testable import AgentRAGPlugin

// MARK: - vec0.dylib 加载测试

@Test func vec0DylibBundledInPackageResources() {
    let url = Bundle.module.url(forResource: "vec0", withExtension: "dylib")
    #expect(url != nil, "vec0.dylib 应存在于 AgentRAGPlugin 的资源 bundle 中")
}

@Test func sqliteVecBackendLoadsSuccessfully() throws {
    let dbURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRAGPluginTests")
        .appendingPathComponent("\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let store = try RAGSQLiteStore(dbURL: dbURL)
    try store.migrate()
    try store.configureVectorBackend(embeddingDimension: 256)

    #expect(store.runtimeInfo.vectorBackend == .sqliteVec,
           "vec0.dylib 加载应成功，实际: \(store.runtimeInfo.note ?? "")")
}

// MARK: - 原有测试

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func searchCodeSchemaDeclaresBoundedControls() throws {
    let schema = RAGCodeSearchTool().inputSchema

    guard case .object(let keys) = schema,
          case .object(let properties) = keys["properties"] else {
        Issue.record("schema should declare properties object")
        return
    }

    if case .object(let topK) = properties["topK"] {
        if case .string(let type) = topK["type"] {
            #expect(type == "integer")
        } else {
            Issue.record("topK type missing")
        }
        if case .int(let minimum) = topK["minimum"] {
            #expect(minimum == RAGCodeSearchTool.minTopK)
        } else {
            Issue.record("topK minimum missing")
        }
        if case .int(let maximum) = topK["maximum"] {
            #expect(maximum == RAGCodeSearchTool.maxTopK)
        } else {
            Issue.record("topK maximum missing")
        }
    } else {
        Issue.record("topK property missing")
    }

    if case .object(let timeout) = properties["timeout"] {
        if case .string(let type) = timeout["type"] {
            #expect(type == "integer")
        } else {
            Issue.record("timeout type missing")
        }
        if case .int(let minimum) = timeout["minimum"] {
            #expect(minimum == Int(RAGCodeSearchTool.minTimeoutSeconds))
        } else {
            Issue.record("timeout minimum missing")
        }
        if case .int(let maximum) = timeout["maximum"] {
            #expect(maximum == Int(RAGCodeSearchTool.maxTimeoutSeconds))
        } else {
            Issue.record("timeout maximum missing")
        }
    } else {
        Issue.record("timeout property missing")
    }
}

@Test func searchCodeNormalizesUserControlledBounds() {
    #expect(RAGCodeSearchTool.normalizedTopK(nil) == RAGCodeSearchTool.defaultTopK)
    #expect(RAGCodeSearchTool.normalizedTopK(-10) == RAGCodeSearchTool.minTopK)
    #expect(RAGCodeSearchTool.normalizedTopK(12) == 12)
    #expect(RAGCodeSearchTool.normalizedTopK(999) == RAGCodeSearchTool.maxTopK)
    #expect(RAGCodeSearchTool.normalizedTimeout(nil) == RAGCodeSearchTool.defaultTimeoutSeconds)
    #expect(RAGCodeSearchTool.normalizedTimeout(0) == RAGCodeSearchTool.minTimeoutSeconds)
    #expect(RAGCodeSearchTool.normalizedTimeout(30) == 30)
    #expect(RAGCodeSearchTool.normalizedTimeout(999) == RAGCodeSearchTool.maxTimeoutSeconds)
}

@Test func keywordSearchFindsUTF16SourceFiles() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRAGPluginTests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let fileURL = projectURL.appendingPathComponent("Sources/UTF16Searchable.swift")
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try """
    struct UTF16Searchable {
        let marker = "needle utf16 keyword target"
    }
    """.write(to: fileURL, atomically: true, encoding: .utf16)

    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "test-search-code",
        toolName: "search_code",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )
    let output = try await RAGCodeSearchTool().execute(
        arguments: [
            "query": .string("needle utf16 keyword target"),
            "mode": .string("keyword"),
            "projectPath": .string(projectURL.path),
        ],
        context: context
    )

    #expect(output.contains("UTF16Searchable.swift"))
    #expect(output.contains("needle utf16 keyword target"))
}

@Test func keywordSearchClampsOversizedTopK() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRAGPluginTests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let sourcesURL = projectURL.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
    for index in 1...25 {
        let fileURL = sourcesURL.appendingPathComponent("Match\(index).swift")
        try """
        struct Match\(index) {
            let marker = "bounded topk target"
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "test-search-code-topk",
        toolName: "search_code",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )
    let output = try await RAGCodeSearchTool().execute(
        arguments: [
            "query": .string("bounded topk target"),
            "mode": .string("keyword"),
            "projectPath": .string(projectURL.path),
            "topK": .int(999),
        ],
        context: context
    )

    #expect(output.contains("Results: \(RAGCodeSearchTool.maxTopK)"))
    #expect(!output.contains("### \(RAGCodeSearchTool.maxTopK + 1)."))
}

@Test func processCaptureHandlesLargeStdoutWithoutPipeBackpressure() async throws {
    let result = try RAGCodeSearchTool.runProcessCapturingStdout(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: [
            "-c",
            """
            i=1
            while [ "$i" -le 300 ]; do
              printf 'rag-grep-%03d-%0512d\\n' "$i" 0
              i=$((i + 1))
            done
            """
        ],
        timeout: 5
    )

    let output = String(data: result?.stdout ?? Data(), encoding: .utf8) ?? ""
    #expect(result?.terminationStatus == 0)
    #expect(output.contains("rag-grep-300-"))
    #expect((result?.stdout.count ?? 0) > 150_000)
}
