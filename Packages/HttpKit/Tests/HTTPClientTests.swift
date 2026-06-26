import Foundation
import Testing
@testable import HttpKit

@Suite("HTTPClient")
struct HTTPClientTests {
    // MARK: - validateResponse

    @Test("validateResponse succeeds for 2xx status")
    func validateResponseSuccess() throws {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let result = try client.validateResponse(response, data: Data("ok".utf8))
        #expect(result.statusCode == 200)
    }

    @Test("validateResponse succeeds for 201 status")
    func validateResponse201() throws {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 201,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let result = try client.validateResponse(response, data: Data())
        #expect(result.statusCode == 201)
    }

    @Test("validateResponse succeeds for 299 status")
    func validateResponse299() throws {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 299,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let result = try client.validateResponse(response, data: Data())
        #expect(result.statusCode == 299)
    }

    @Test("validateResponse throws invalidResponse for non-HTTPURLResponse")
    func validateResponseInvalidResponse() {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        do {
            _ = try client.validateResponse(response, data: Data())
            Issue.record("Expected error to be thrown")
        } catch let error as HTTPClientError {
            if case .invalidResponse = error {
                // expected
            } else {
                Issue.record("Expected invalidResponse, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("validateResponse throws httpError for 400 status")
    func validateResponse400() {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        do {
            _ = try client.validateResponse(response, data: Data("Bad Request".utf8))
            Issue.record("Expected error to be thrown")
        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, message) = error {
                #expect(statusCode == 400)
                #expect(message.contains("Bad Request"))
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("validateResponse throws httpError for 500 status")
    func validateResponse500() {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        do {
            _ = try client.validateResponse(response, data: Data("Internal Server Error".utf8))
            Issue.record("Expected error to be thrown")
        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, _) = error {
                #expect(statusCode == 500)
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("validateResponse error message includes URL and response body")
    func validateResponseErrorMessageFormat() {
        let client = HTTPClient()
        let url = URL(string: "https://api.example.com/v1/data")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 403,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        do {
            _ = try client.validateResponse(response, data: Data("Forbidden".utf8))
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, message) = error {
                #expect(statusCode == 403)
                #expect(message.contains("api.example.com"))
                #expect(message.contains("Forbidden"))
                #expect(!message.contains("HTTP Error"))
            } else {
                Issue.record("Expected httpError")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("validateResponse handles non-UTF8 error body gracefully")
    func validateResponseNonUTF8Body() {
        let client = HTTPClient()
        let url = URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let nonUTF8Data = Data([0xFF, 0xFE, 0x00])
        do {
            _ = try client.validateResponse(response, data: nonUTF8Data)
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, message) = error {
                #expect(statusCode == 500)
                #expect(message.contains("Unknown error"))
            } else {
                Issue.record("Expected httpError")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - sanitizeHeaders

    @Test("sanitizeHeaders masks authorization headers")
    func sanitizeHeadersMasksAuthorization() {
        let headers = HTTPClient.sanitizeHeaders([
            "Authorization": "Bearer token123",
            "X-API-Key": "my-secret-key",
            "Content-Type": "application/json",
            "X-Custom-Token": "tok",
            "Custom-Key": "value",
            "Accept": "text/html",
        ])

        #expect(headers["Authorization"] == "***")
        #expect(headers["X-API-Key"] == "***")
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["X-Custom-Token"] == "***")
        #expect(headers["Custom-Key"] == "***")
        #expect(headers["Accept"] == "text/html")
    }

    @Test("sanitizeHeaders returns empty for empty input")
    func sanitizeHeadersEmpty() {
        let headers = HTTPClient.sanitizeHeaders([:])
        #expect(headers.isEmpty)
    }

    // MARK: - maskSensitiveValue

    @Test("maskSensitiveValue masks long sensitive values")
    func maskSensitiveLongValue() {
        // "Bearer abcdefgh" has 15 chars (including space), prefix 4 + suffix 4 = 8, stars = max(3, 15-8) = 7
        let result = HTTPClient.maskSensitiveValue(key: "Authorization", value: "Bearer abcdefgh")
        #expect(result == "Bear*******efgh")
    }

    @Test("maskSensitiveValue masks short sensitive values")
    func maskSensitiveShortValue() {
        let result = HTTPClient.maskSensitiveValue(key: "Authorization", value: "short")
        #expect(result == "sh***rt")
    }

    @Test("maskSensitiveValue returns plain value for non-sensitive keys")
    func maskSensitiveNonSensitive() {
        let result = HTTPClient.maskSensitiveValue(key: "Content-Type", value: "application/json")
        #expect(result == "application/json")
    }

    // MARK: - init with custom configuration

    @Test("init accepts custom configuration")
    func initCustomConfiguration() {
        let client = HTTPClient(
            timeoutIntervalForRequest: 10,
            timeoutIntervalForResource: 30
        ) { config in
            config.httpAdditionalHeaders = ["X-Custom": "value"]
        }
        // Should not crash; client is usable
        #expect(type(of: client) == HTTPClient.self)
    }
}
