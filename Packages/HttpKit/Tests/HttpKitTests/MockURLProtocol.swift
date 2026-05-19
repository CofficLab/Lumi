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

// MARK: - All Data-Based Networking Tests (serialized to avoid MockURLProtocol interference)

@Suite("HTTPClient Networking", .serialized)
struct HTTPClientNetworkingTests {
    // MARK: - sendJSONRequest (original)

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
            if case .requestFailed = error {
                // expected
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

    // MARK: - sendRequest (new)

    @Test("sendRequest returns data for successful GET")
    func sendRequestSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"id\":1,\"name\":\"test\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "GET"

        let data = try await client.sendRequest(request: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["id"] as? Int == 1)
        #expect(json?["name"] as? String == "test")
    }

    @Test("sendRequestWithResponse returns data and HTTPURLResponse")
    func sendRequestWithResponseSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["X-Custom": "yes"])!,
                Data("{\"id\":2,\"name\":\"resp\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "DELETE"

        let (data, response) = try await client.sendRequestWithResponse(request: request)
        #expect(response.statusCode == 200)
        #expect(response.value(forHTTPHeaderField: "X-Custom") == "yes")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["id"] as? Int == 2)
    }

    @Test("sendRequest throws httpError for 404")
    func sendRequest404() async {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("Not Found".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/missing")!)

        do {
            _ = try await client.sendRequest(request: request)
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

    @Test("sendRequest throws requestFailed for network error")
    func sendRequestNetworkError() async {
        MockURLProtocol.setHandler { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/offline")!)

        do {
            _ = try await client.sendRequest(request: request)
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

    // MARK: - sendEncodableRequest (new)

    @Test("sendEncodableRequest encodes body and returns data")
    func sendEncodableSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"id\":99,\"name\":\"created\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await client.sendEncodableRequest(request: request, body: SendEncodableTestRequest(title: "hello", value: 42))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["id"] as? Int == 99)
    }

    @Test("sendEncodableRequestWithResponse returns response metadata")
    func sendEncodableWithResponse() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 201, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"id\":1,\"name\":\"ok\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "PUT"

        let (_, response) = try await client.sendEncodableRequestWithResponse(
            request: request,
            body: SendEncodableTestRequest(title: "update", value: 7)
        )
        #expect(response.statusCode == 201)
    }

    // MARK: - sendDecodableRequest (new)

    @Test("sendDecodableRequest decodes GET response into typed object")
    func sendDecodableSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"id\":42,\"name\":\"decoded\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "GET"

        let result = try await client.sendDecodableRequest(request: request, as: DecodableTestResponse.self)
        #expect(result == DecodableTestResponse(id: 42, name: "decoded"))
    }

    @Test("sendDecodableRequest throws decodingFailed for invalid JSON")
    func sendDecodableFailure() async {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("not json at all".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/api")!)

        do {
            _ = try await client.sendDecodableRequest(request: request, as: DecodableTestResponse.self)
            Issue.record("Expected decodingFailed error")
        } catch let error as HTTPClientError {
            if case .decodingFailed = error {
                // expected
            } else {
                Issue.record("Expected decodingFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("sendJSONDecodableRequest sends JSON body and decodes response")
    func sendJSONDecodableSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"id\":7,\"name\":\"json-decoded\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"

        let result = try await client.sendJSONDecodableRequest(
            request: request,
            body: ["key": "value"],
            as: DecodableTestResponse.self
        )
        #expect(result == DecodableTestResponse(id: 7, name: "json-decoded"))
    }

    @Test("sendEncodableDecodableRequest encodes body and decodes response")
    func sendEncodableDecodableSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("{\"id\":3,\"name\":\"roundtrip\"}".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"

        let result = try await client.sendEncodableDecodableRequest(
            request: request,
            body: SendEncodableTestRequest(title: "test", value: 1),
            as: DecodableTestResponse.self
        )
        #expect(result == DecodableTestResponse(id: 3, name: "roundtrip"))
    }

    // MARK: - sendDataRequestWithResponse (new)

    @Test("sendDataRequestWithResponse sends raw body and returns response")
    func sendDataSuccess() async throws {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        var request = URLRequest(url: URL(string: "https://mock.test/api")!)
        request.httpMethod = "POST"

        let (data, response) = try await client.sendDataRequestWithResponse(
            request: request,
            body: Data("raw-payload".utf8)
        )
        #expect(response.statusCode == 200)
        #expect(data == Data("ok".utf8))
    }

    @Test("sendDataRequestWithResponse throws httpError for 500")
    func sendDataError() async {
        MockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 500, httpVersion: "HTTP/1.1", headerFields: nil)!,
                Data("Server Error".utf8)
            )
        }
        defer { MockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [MockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/api")!)

        do {
            _ = try await client.sendDataRequestWithResponse(request: request, body: Data())
            Issue.record("Expected error")
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
}

// MARK: - Test Models (file-private, used by tests above)

private struct DecodableTestResponse: Decodable, Equatable {
    let id: Int
    let name: String
}

private struct SendEncodableTestRequest: Codable, Equatable {
    let title: String
    let value: Int
}
