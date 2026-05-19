import Foundation
import Testing
@testable import HttpKit

// MARK: - Thread-safe mutable wrapper for test assertions

final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - MockURLProtocol

/// A `URLProtocol` subclass that intercepts URLSession data requests for testing.
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var _handler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    static func setHandler(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data?)) {
        _handler = handler
    }

    static func reset() {
        _handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self._handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - StreamingMockURLProtocol

/// A `URLProtocol` subclass for streaming (bytes) responses.
final class StreamingMockURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var _handler: ((URLRequest) throws -> (HTTPURLResponse, [Data]))?

    static func setHandler(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, [Data])) {
        _handler = handler
    }

    static func reset() {
        _handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self._handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, chunks) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks {
                client?.urlProtocol(self, didLoad: chunk)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helper

extension HTTPClient {
    /// Creates an `HTTPClient` that uses custom URLProtocol classes for all requests.
    static func mockClient(protocols: [AnyClass]) -> HTTPClient {
        HTTPClient { config in
            config.protocolClasses = protocols
        }
    }
}

// MARK: - sendJSONRequest Tests

@Suite("HTTPClient Networking", .serialized)
struct HTTPClientNetworkingTests {
    @Test("sendJSONRequest returns data for successful response")
    func sendJSONRequestSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"ok\":true}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"

        let data = try await client.sendJSONRequest(request: request, body: ["key": "value"])
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["ok"] as? Bool == true)
    }

    @Test("sendJSONRequestWithResponse returns data and response for 200")
    func sendJSONRequestWithResponseSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"result\":\"success\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"

        let (data, response) = try await client.sendJSONRequestWithResponse(request: request, body: ["q": "test"])
        #expect(response.statusCode == 200)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["result"] as? String == "success")
    }

    @Test("sendJSONRequestWithResponse throws httpError for 404")
    func sendJSONRequestWithResponse404() async {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("Not Found".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/missing")!)
        request.httpMethod = "POST"

        do {
            _ = try await client.sendJSONRequestWithResponse(request: request, body: [:])
            Issue.record("Expected error to be thrown")
        } catch let error as HTTPClientError {
            if case let .httpError(code, _) = error {
                #expect(code == 404)
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendJSONRequestWithResponse throws httpError for 500")
    func sendJSONRequestWithResponse500() async {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("Server Error".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/error")!)
        request.httpMethod = "POST"

        do {
            _ = try await client.sendJSONRequestWithResponse(request: request, body: [:])
            Issue.record("Expected error to be thrown")
        } catch let error as HTTPClientError {
            if case let .httpError(code, _) = error {
                #expect(code == 500)
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendJSONRequestWithResponse rethrows HTTPClientError from validateResponse")
    func sendJSONRequestWithResponseRethrowsHTTPClientError() async {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 403, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("Forbidden".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/forbidden")!)

        do {
            _ = try await client.sendJSONRequestWithResponse(request: request, body: [:])
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case let .httpError(code, msg) = error {
                #expect(code == 403)
                #expect(msg.contains("Forbidden"))
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendJSONRequestWithResponse throws requestFailed for network error")
    func sendJSONRequestWithResponseNetworkError() async {
        MockURLProtocol.setHandler { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/offline")!)

        do {
            _ = try await client.sendJSONRequestWithResponse(request: request, body: [:])
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case .requestFailed = error {
                // expected
            } else {
                Issue.record("Expected requestFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendJSONRequest wraps CancellationError from URLProtocol as requestFailed")
    func sendJSONRequestCancellation() async {
        MockURLProtocol.setHandler { _ in
            throw CancellationError()
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/cancel")!)

        do {
            _ = try await client.sendJSONRequest(request: request, body: [:])
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            // URLSession wraps CancellationError into a URLError, so it hits the generic catch
            if case .requestFailed = error {
                // expected: URLSession wraps it
            } else {
                Issue.record("Expected requestFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendJSONRequestWithResponse wraps CancellationError from URLProtocol as requestFailed")
    func sendJSONRequestWithResponseCancellation() async {
        MockURLProtocol.setHandler { _ in
            throw CancellationError()
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/cancel")!)

        do {
            _ = try await client.sendJSONRequestWithResponse(request: request, body: [:])
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case .requestFailed = error {
                // expected
            } else {
                Issue.record("Expected requestFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - sendStreamingJSONRequest Tests

@Suite("HTTPClient Streaming", .serialized)
struct HTTPClientStreamingTests {
    @Test("sendStreamingJSONRequest calls onRequestStart with metadata")
    func streamingCallsOnRequestStart() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: message\ndata: hello\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let receivedMetadata = Box<HTTPRequestMetadata?>(nil)
        try await client.sendStreamingJSONRequest(
            request: request,
            body: ["prompt": "test"],
            onRequestStart: { metadata in
                receivedMetadata.value = metadata
            },
            onEvent: { _ in true }
        )

        #expect(receivedMetadata.value != nil)
        #expect(receivedMetadata.value?.method == "POST")
        #expect(receivedMetadata.value?.url == "https://mock.test/stream")
        #expect(receivedMetadata.value?.requestBodySizeBytes ?? 0 > 0)
    }

    @Test("sendStreamingJSONRequest calls onEvent with SSE data")
    func streamingCallsOnEvent() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("data: hello world\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let receivedEvents = Box<[Data]>([])
        try await client.sendStreamingJSONRequest(
            request: request,
            body: ["prompt": "test"],
            onEvent: { data in
                receivedEvents.value.append(data)
                return true
            }
        )

        #expect(receivedEvents.value.count >= 1)
        // The SSE parser finds \n\n delimiter and delivers the data before it
        let firstEvent = receivedEvents.value.first
        #expect(firstEvent != nil)
        let expectedContent = Data("data: hello world".utf8)
        #expect(firstEvent == expectedContent)
    }

    @Test("sendStreamingJSONRequest stops when onEvent returns false")
    func streamingStopsOnFalseReturn() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event1\n\nevent2\n\nevent3\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let eventCount = Box(0)
        try await client.sendStreamingJSONRequest(
            request: request,
            body: ["prompt": "test"],
            onEvent: { _ in
                eventCount.value += 1
                return false // stop after first event
            }
        )

        #expect(eventCount.value == 1)
    }

    @Test("sendStreamingJSONRequest throws httpError for non-2xx response")
    func streamingThrowsForNon2xx() async {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 429, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("Rate Limited".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        do {
            try await client.sendStreamingJSONRequest(
                request: request,
                body: [:],
                onEvent: { _ in true }
            )
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case let .httpError(code, msg) = error {
                #expect(code == 429)
                #expect(msg.contains("Rate Limited"))
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendStreamingJSONRequest throws requestFailed for network error")
    func streamingThrowsForNetworkError() async {
        StreamingMockURLProtocol.setHandler { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        do {
            try await client.sendStreamingJSONRequest(
                request: request,
                body: [:],
                onEvent: { _ in true }
            )
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case .requestFailed = error {
                // expected
            } else {
                Issue.record("Expected requestFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendStreamingJSONRequest handles CRLF delimiters")
    func streamingHandlesCRLF() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: ping\r\n\r\nevent: pong\r\n\r\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let events = Box<[Data]>([])
        try await client.sendStreamingJSONRequest(
            request: request,
            body: [:],
            onEvent: { data in
                events.value.append(data)
                return true
            }
        )

        #expect(events.value.count == 2)
        #expect(events.value[0] == Data("event: ping".utf8))
        #expect(events.value[1] == Data("event: pong".utf8))
    }

    @Test("sendStreamingJSONRequest handles trailing data without delimiter")
    func streamingHandlesTrailingData() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: final".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let events = Box<[Data]>([])
        try await client.sendStreamingJSONRequest(
            request: request,
            body: [:],
            onEvent: { data in
                events.value.append(data)
                return true
            }
        )

        #expect(events.value.count == 1)
        #expect(events.value[0] == Data("event: final".utf8))
    }

    @Test("sendStreamingJSONRequest skips empty events between delimiters")
    func streamingSkipsEmptyEvents() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                // Double \n\n right at start → empty event should be skipped
                [Data("\n\nevent: real\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let events = Box<[Data]>([])
        try await client.sendStreamingJSONRequest(
            request: request,
            body: [:],
            onEvent: { data in
                events.value.append(data)
                return true
            }
        )

        #expect(events.value.count == 1)
        #expect(events.value[0] == Data("event: real".utf8))
    }

    @Test("sendStreamingJSONRequest handles multiple events across separate chunks")
    func streamingMultipleChunks() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [
                    Data("event: chunk1\n\n".utf8),
                    Data("event: chunk2\n\n".utf8),
                ]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/stream")!)
        request.httpMethod = "POST"

        let events = Box<[Data]>([])
        try await client.sendStreamingJSONRequest(
            request: request,
            body: [:],
            onEvent: { data in
                events.value.append(data)
                return true
            }
        )

        #expect(events.value.count == 2)
        #expect(events.value[0] == Data("event: chunk1".utf8))
        #expect(events.value[1] == Data("event: chunk2".utf8))
    }

    @Test("sendStreamingJSONRequest wraps CancellationError from URLProtocol as requestFailed")
    func streamingCancellationError() async {
        StreamingMockURLProtocol.setHandler { _ in
            throw CancellationError()
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        do {
            try await client.sendStreamingJSONRequest(
                request: request,
                body: [:],
                onEvent: { _ in true }
            )
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            // URLSession wraps CancellationError into URLError
            if case .requestFailed = error {
                // expected
            } else {
                Issue.record("Expected requestFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
