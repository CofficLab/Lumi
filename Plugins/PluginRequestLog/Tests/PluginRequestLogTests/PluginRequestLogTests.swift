import Foundation
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
