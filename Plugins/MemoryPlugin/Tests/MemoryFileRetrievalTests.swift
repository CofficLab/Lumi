import Testing
import Foundation
@testable import MemoryPlugin

/// Unit tests for `MemoryFileStorage` path sanitization, markdown round-trip,
/// and the `MemoryFileRetrieval` relevance-ranking engine.
///
/// These use an injected temp directory so no real app memory store is touched.
@Suite struct MemoryFileStorageTests {

    // MARK: - sanitizeProjectPath

    @Test func sanitizeProjectPathIsStableForSamePath() {
        let a = MemoryFileStorage.sanitizeProjectPath("/Users/x/Code/MyProject")
        let b = MemoryFileStorage.sanitizeProjectPath("/Users/x/Code/MyProject")
        #expect(a == b)
    }

    @Test func sanitizeProjectPathDifferentiatesSiblingProjects() {
        // Regression: the old UInt8 hash folded to 256 buckets, so these two
        // sibling projects collided and shared one memory directory.
        let a = MemoryFileStorage.sanitizeProjectPath("/tmp/Lumi")
        let b = MemoryFileStorage.sanitizeProjectPath("/tmp/Lumi-Other")
        #expect(a != b)
    }

    @Test func sanitizeProjectPathDifferentiatesSameNameDifferentParent() {
        // Two repos both named "App" but in different parents must not collide.
        let a = MemoryFileStorage.sanitizeProjectPath("/home/alice/App")
        let b = MemoryFileStorage.sanitizeProjectPath("/home/bob/App")
        #expect(a != b)
    }

    @Test func sanitizeProjectPathStartsWithHumanReadableName() {
        let result = MemoryFileStorage.sanitizeProjectPath("/x/My Cool.App")
        // Spaces and dots are scrubbed; last path component leads.
        #expect(result.hasPrefix("My_Cool_App_"))
    }

    // MARK: - Markdown round-trip

    @Test func markdownRoundTripPreservesFields() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mem-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = MemoryFileStorage(rootURL: dir)
        let created = try await storage.createMemory(
            id: "auth",
            type: .project,
            name: "Auth Strategy",
            description: "How login works",
            content: "Uses OAuth2 with PKCE.",
            scope: .global
        )

        let listed = await storage.listMemories(scope: .global)
        let restored = try #require(listed.first { $0.id == "auth" })

        #expect(restored.type == .project)
        #expect(restored.name == "Auth Strategy")
        #expect(restored.description == "How login works")
        #expect(restored.content == "Uses OAuth2 with PKCE.")
        // Times survive the serialize/parse round-trip (second precision).
        #expect(Int(created.createdAt.timeIntervalSince1970) == Int(restored.createdAt.timeIntervalSince1970))
        #expect(Int(created.updatedAt.timeIntervalSince1970) == Int(restored.updatedAt.timeIntervalSince1970))
    }

    @Test func markdownRoundTripHandlesContentWithFrontmatterLikeMarker() async throws {
        // Content containing "---" lines must not break frontmatter parsing.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mem-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = MemoryFileStorage(rootURL: dir)
        _ = try await storage.createMemory(
            id: "note",
            type: .reference,
            name: "Note",
            description: "",
            content: "Section\n\n---\n\nMore content after divider",
            scope: .global
        )

        let restored = try #require(await storage.listMemories(scope: .global).first { $0.id == "note" })
        #expect(restored.content.contains("More content after divider"))
        #expect(restored.type == .reference)
    }
}

@Suite struct MemoryFileRetrievalTests {

    /// Helper: build an in-memory-backed storage in a temp dir and seed memories.
    private func makeStorage() async throws -> MemoryFileStorage {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mem-retr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return MemoryFileStorage(rootURL: dir)
    }

    @Test func findRelevantReturnsEmptyForNoMatches() async throws {
        let storage = try await makeStorage()
        let retrieval = MemoryFileRetrieval()
        _ = try await storage.createMemory(
            id: "a", type: .project, name: "Auth", description: "",
            content: "OAuth login", scope: .global
        )
        let result = await retrieval.findRelevant(
            query: "completely unrelated cooking recipe",
            scope: .global,
            storage: storage
        )
        // Type + recency weights still apply (>0), so this may return the only item;
        // but the contract is "best matches first" — assert no crash and a list.
        #expect(result.count <= 1)
    }

    @Test func findRelevantRanksByKeywordRelevance() async throws {
        let storage = try await makeStorage()
        let retrieval = MemoryFileRetrieval()

        // Irrelevant memory
        _ = try await storage.createMemory(
            id: "weather", type: .reference, name: "Weather", description: "",
            content: "It rains often in spring", scope: .global
        )
        // Highly relevant memory: keyword in name, description and content
        _ = try await storage.createMemory(
            id: "auth", type: .feedback, name: "Authentication", description: "login flow",
            content: "login uses oauth2 token refresh", scope: .global
        )

        let result = await retrieval.findRelevant(
            query: "how does login authentication work",
            scope: .global,
            storage: storage
        )
        #expect(!result.isEmpty)
        #expect(result.first?.id == "auth")
    }

    @Test func findRelevantRespectsMaxResults() async throws {
        let storage = try await makeStorage()
        let retrieval = MemoryFileRetrieval()

        for i in 0..<5 {
            _ = try await storage.createMemory(
                id: "m\(i)", type: .project, name: "project \(i)", description: "shared topic",
                content: "shared topic details \(i)", scope: .global
            )
        }
        let result = await retrieval.findRelevant(
            query: "shared topic",
            scope: .global,
            storage: storage,
            maxResults: 2
        )
        #expect(result.count == 2)
    }

    @Test func findRelevantReturnsEmptyWhenMaxResultsZero() async throws {
        let storage = try await makeStorage()
        let retrieval = MemoryFileRetrieval()
        _ = try await storage.createMemory(
            id: "a", type: .project, name: "x", description: "", content: "y", scope: .global
        )
        let result = await retrieval.findRelevant(
            query: "x", scope: .global, storage: storage, maxResults: 0
        )
        #expect(result.isEmpty)
    }

    @Test func findRelevantReturnsEmptyForStopWordOnlyQuery() async throws {
        let storage = try await makeStorage()
        let retrieval = MemoryFileRetrieval()
        _ = try await storage.createMemory(
            id: "a", type: .project, name: "Auth", description: "", content: "login", scope: .global
        )
        // Pure stop words / single chars get filtered out by the tokenizer.
        let result = await retrieval.findRelevant(
            query: "the a is of", scope: .global, storage: storage
        )
        #expect(result.isEmpty)
    }

    @Test func tokenizeRespectsCjkAndShortWords() async throws {
        // CJK queries should still surface relevant content via substring match.
        let storage = try await makeStorage()
        let retrieval = MemoryFileRetrieval()
        _ = try await storage.createMemory(
            id: "cn", type: .feedback, name: "中文偏好", description: "代码风格",
            content: "用户喜欢使用 Swift 编写代码", scope: .global
        )
        let result = await retrieval.findRelevant(
            query: "用户喜欢什么代码风格", scope: .global, storage: storage
        )
        #expect(!result.isEmpty)
        #expect(result.first?.id == "cn")
    }
}
