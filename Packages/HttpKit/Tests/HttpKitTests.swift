import Foundation
import Testing
@testable import HttpKit

@Suite("HttpKit")
struct HttpKitTests {
    @Test("formats request body sizes")
    func formatsRequestBodySizes() {
        let metadata = HTTPRequestMetadata(
            requestId: UUID(),
            method: "POST",
            url: "https://example.com",
            requestHeaders: [:],
            requestBodySizeBytes: 2048,
            requestBodyPreview: nil,
            sentAt: Date()
        )

        #expect(metadata.formattedBodySize == "2.00 KB")
    }

    @Test("sanitizes sensitive headers")
    func sanitizesSensitiveHeaders() {
        let headers = HTTPClient.sanitizeHeaders([
            "Authorization": "Bearer secret",
            "Content-Type": "application/json",
            "x-api-key": "secret",
        ])

        #expect(headers["Authorization"] == "***")
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["x-api-key"] == "***")
    }

    @Test("masks sensitive values")
    func masksSensitiveValues() {
        #expect(HTTPClient.maskSensitiveValue(key: "Authorization", value: "Bearer abcdef") == "Bear*****cdef")
        #expect(HTTPClient.maskSensitiveValue(key: "Content-Type", value: "application/json") == "application/json")
    }
}
