import Foundation
import HttpKit
import SwiftData
import Testing
@testable import PluginRequestLog

@Test func historyStoreRecoversWhenDatabaseDirectoryIsBlocked() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("request-log-store-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let blockedDirectory = root.appendingPathComponent("RequestLogPlugin", isDirectory: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let container = RequestLogHistoryManager.makeContainer(databaseRootURL: root)
    let context = ModelContext(container)
    let item = RequestLogItem(
        requestId: UUID(),
        timestamp: Date(),
        method: "GET",
        requestURL: "https://example.com",
        requestHeadersJSON: nil,
        requestBodySize: 0,
        requestBodyPreview: nil,
        responseStatusCode: 200,
        responseHeadersJSON: nil,
        responseBodySize: 2,
        responseBodyPreview: "OK",
        isSuccess: true,
        errorMessage: nil,
        duration: 0.1
    )

    context.insert(item)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<RequestLogItem>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.requestURL == "https://example.com")
}

@Test func addReportsSuccessfulPersistence() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("request-log-add-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = RequestLogHistoryManager(databaseRootURL: root)
    let metadata = HTTPRequestMetadata(
        requestId: UUID(),
        method: "POST",
        url: "https://example.com/chat",
        requestHeaders: ["Content-Type": "application/json"],
        requestBodySizeBytes: 2,
        requestBodyPreview: "{}",
        sentAt: Date(),
        responseStatusCode: 200,
        responseHeaders: ["Content-Type": "application/json"],
        responseBodySizeBytes: 11,
        responseBodyPreview: "{\"ok\":true}",
        duration: 0.25
    )

    let saved = await manager.add(metadata: metadata)
    let latest = await manager.getLatest(limit: 10)

    #expect(saved)
    #expect(latest.count == 1)
    #expect(latest.first?.requestURL == "https://example.com/chat")
    #expect(latest.first?.method == "POST")
}

@Test func requestLogQueriesClampPaginationBeforeFetching() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("request-log-pagination-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = RequestLogHistoryManager(databaseRootURL: root)
    for index in 0..<3 {
        let metadata = HTTPRequestMetadata(
            requestId: UUID(),
            method: "GET",
            url: "https://example.com/\(index)",
            requestHeaders: [:],
            requestBodySizeBytes: 0,
            requestBodyPreview: nil,
            sentAt: Date().addingTimeInterval(Double(index)),
            responseStatusCode: index == 0 ? 500 : 200,
            responseHeaders: [:],
            responseBodySizeBytes: nil,
            responseBodyPreview: nil,
            duration: 0.1,
            error: index == 0
                ? NSError(domain: "RequestLogTests", code: 500)
                : nil
        )
        _ = await manager.add(metadata: metadata)
    }

    let latest = await manager.getLatest(limit: -10, offset: -50)
    let failed = await manager.query(isSuccess: false, limit: 0, offset: -1)

    #expect(latest.count == 1)
    #expect(latest.first?.requestURL == "https://example.com/2")
    #expect(failed.count == 1)
    #expect(failed.first?.responseStatusCode == 500)
}

@MainActor
@Test func requestLogBrowserUsesFilteredCountsForPagination() {
    let viewModel = RequestLogBrowserViewModel()
    viewModel.stats = RequestLogStats(
        totalRequests: 125,
        successCount: 120,
        failedCount: 5
    )

    #expect(viewModel.totalPages == 3)

    viewModel.filterSuccess = false
    #expect(viewModel.totalPages == 1)

    viewModel.filterSuccess = true
    #expect(viewModel.totalPages == 3)
}
