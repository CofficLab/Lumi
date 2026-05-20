import Foundation
import Testing
@testable import HttpKit

@Suite("HTTPRequestMetadata")
struct HTTPRequestMetadataTests {
    // MARK: - formattedBodySize

    @Test("formats bytes when size < 1 KB")
    func formatsBytes() {
        let metadata = makeMetadata(size: 512)
        #expect(metadata.formattedBodySize == "512 bytes")
    }

    @Test("formats KB when size >= 1 KB and < 1 MB")
    func formatsKilobytes() {
        let metadata = makeMetadata(size: 2048)
        #expect(metadata.formattedBodySize == "2.00 KB")
    }

    @Test("formats MB when size >= 1 MB and < 1 GB")
    func formatsMegabytes() {
        let metadata = makeMetadata(size: 2 * 1024 * 1024 + 512 * 1024) // 2.5 MB
        #expect(metadata.formattedBodySize == "2.50 MB")
    }

    @Test("formats GB when size >= 1 GB")
    func formatsGigabytes() {
        let metadata = makeMetadata(size: 3 * 1024 * 1024 * 1024) // 3 GB
        #expect(metadata.formattedBodySize == "3.00 GB")
    }

    @Test("formats zero bytes")
    func formatsZeroBytes() {
        let metadata = makeMetadata(size: 0)
        #expect(metadata.formattedBodySize == "0 bytes")
    }

    // MARK: - isSuccess

    @Test("isSuccess is true when no error")
    func isSuccessTrue() {
        let metadata = makeMetadata(size: 0)
        #expect(metadata.isSuccess == true)
    }

    @Test("isSuccess is false when error is set")
    func isSuccessFalse() {
        let metadata = HTTPRequestMetadata(
            requestId: UUID(),
            method: "POST",
            url: "https://example.com",
            requestHeaders: [:],
            requestBodySizeBytes: 0,
            requestBodyPreview: nil,
            sentAt: Date(),
            error: HTTPClientError.invalidResponse
        )
        #expect(metadata.isSuccess == false)
    }

    // MARK: - Initializer

    @Test("initializer sets all properties correctly")
    func initializerSetsProperties() {
        let id = UUID()
        let now = Date()
        let metadata = HTTPRequestMetadata(
            requestId: id,
            method: "GET",
            url: "https://example.com/api",
            requestHeaders: ["Content-Type": "application/json"],
            requestBodySizeBytes: 1024,
            requestBodyPreview: "{\"key\":\"value\"}",
            sentAt: now,
            responseStatusCode: 200,
            responseHeaders: ["X-Request-Id": "abc"],
            duration: 1.5
        )

        #expect(metadata.requestId == id)
        #expect(metadata.method == "GET")
        #expect(metadata.url == "https://example.com/api")
        #expect(metadata.requestHeaders == ["Content-Type": "application/json"])
        #expect(metadata.requestBodySizeBytes == 1024)
        #expect(metadata.requestBodyPreview == "{\"key\":\"value\"}")
        #expect(metadata.sentAt == now)
        #expect(metadata.responseStatusCode == 200)
        #expect(metadata.responseHeaders == ["X-Request-Id": "abc"])
        #expect(metadata.duration == 1.5)
        #expect(metadata.error == nil)
    }
}

// MARK: - Helper

private func makeMetadata(size: Int) -> HTTPRequestMetadata {
    HTTPRequestMetadata(
        requestId: UUID(),
        method: "POST",
        url: "https://example.com",
        requestHeaders: [:],
        requestBodySizeBytes: size,
        requestBodyPreview: nil,
        sentAt: Date()
    )
}
