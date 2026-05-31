import Foundation
import Testing
@testable import HttpKit

// MARK: - All Streaming Tests (serialized to avoid StreamingMockURLProtocol interference)

@Suite("HTTPClient Streaming", .serialized)
struct HTTPClientStreamingTests {
    // MARK: - sendStreamingJSONRequest (original)

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
                return false
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
            if case .requestFailed = error {
                // expected
            } else {
                Issue.record("Expected requestFailed, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - sendStreamingRequest line-by-line (new)

    @Test("sendStreamingRequest onLine receives individual lines including empty lines")
    func streamingLineByLine() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("line1\nline2\nline3".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        let receivedLines = Box<[String]>([])
        try await client.sendStreamingRequest(request: request) { line in
            receivedLines.value.append(line)
            return true
        }

        #expect(receivedLines.value == ["line1", "line2", "line3"])
    }

    @Test("sendStreamingRequest onLine preserves UTF-8 text")
    func streamingLineByLinePreservesUTF8Text() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("data: 你好 🌟\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        let receivedLines = Box<[String]>([])
        try await client.sendStreamingRequest(request: request) { line in
            receivedLines.value.append(line)
            return true
        }

        #expect(receivedLines.value == ["data: 你好 🌟", ""])
    }

    @Test("sendStreamingRequest onLine accepts CR-only line endings")
    func streamingLineByLineAcceptsCROnlyLineEndings() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("line1\rline2\r\r".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        let receivedLines = Box<[String]>([])
        try await client.sendStreamingRequest(request: request) { line in
            receivedLines.value.append(line)
            return true
        }

        #expect(receivedLines.value == ["line1", "line2", ""])
    }

    @Test("sendStreamingRequest onLine stops when callback returns false")
    func streamingLineStopsOnFalse() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("a\nb\nc\nd".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        let receivedLines = Box<[String]>([])
        try await client.sendStreamingRequest(request: request) { line in
            receivedLines.value.append(line)
            return receivedLines.value.count < 2
        }

        #expect(receivedLines.value.count == 2)
        #expect(receivedLines.value == ["a", "b"])
    }

    @Test("sendStreamingRequest throws httpError for non-2xx (line mode)")
    func streamingLineNon2xx() async {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("Unauthorized".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/stream")!)

        do {
            try await client.sendStreamingRequest(request: request) { _ in true }
            Issue.record("Expected error")
        } catch let error as HTTPClientError {
            if case let .httpError(code, msg) = error {
                #expect(code == 401)
                #expect(msg.contains("Unauthorized"))
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - sendStreamingRequest SSE event (new)

    @Test("sendStreamingRequest onEvent parses SSE events")
    func streamingSSEEvents() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: endpoint\ndata: /post-url\n\nevent: message\ndata: hello world\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        struct SSEEvent {
            let event: String?
            let data: [String]
            let id: String?
        }

        let receivedEvents = Box<[SSEEvent]>([])
        try await client.sendStreamingRequest(request: request) { event, data, id in
            receivedEvents.value.append(SSEEvent(event: event, data: data, id: id))
            return true
        }

        #expect(receivedEvents.value.count == 2)
        #expect(receivedEvents.value[0].event == "endpoint")
        #expect(receivedEvents.value[0].data == ["/post-url"])
        #expect(receivedEvents.value[0].id == nil)
        #expect(receivedEvents.value[1].event == "message")
        #expect(receivedEvents.value[1].data == ["hello world"])
    }

    @Test("sendStreamingRequest onEvent handles multi-line data")
    func streamingSSEMultiLineData() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("data: line1\ndata: line2\ndata: line3\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let receivedData = Box<[[String]]>([])
        try await client.sendStreamingRequest(request: request) { _, data, _ in
            receivedData.value.append(data)
            return true
        }

        #expect(receivedData.value.count == 1)
        #expect(receivedData.value[0] == ["line1", "line2", "line3"])
    }

    @Test("sendStreamingRequest onEvent preserves UTF-8 data")
    func streamingSSEPreservesUTF8Data() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: message\ndata: 你好 🌟\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let receivedData = Box<[[String]]>([])
        try await client.sendStreamingRequest(request: request) { _, data, _ in
            receivedData.value.append(data)
            return true
        }

        #expect(receivedData.value == [["你好 🌟"]])
    }

    @Test("sendStreamingRequest onEvent accepts CR-only event delimiters")
    func streamingSSEAcceptsCROnlyEventDelimiters() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: message\rdata: hello\r\r".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let receivedData = Box<[[String]]>([])
        try await client.sendStreamingRequest(request: request) { _, data, _ in
            receivedData.value.append(data)
            return true
        }

        #expect(receivedData.value == [["hello"]])
    }

    @Test("sendStreamingRequest onEvent handles event id")
    func streamingSSEEventId() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("id: 42\ndata: payload\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let receivedId = Box<String?>(nil)
        try await client.sendStreamingRequest(request: request) { _, _, id in
            receivedId.value = id
            return true
        }

        #expect(receivedId.value == "42")
    }

    @Test("sendStreamingRequest onEvent skips comment lines")
    func streamingSSECommentLines() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data(": this is a comment\ndata: real\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let receivedData = Box<[[String]]>([])
        try await client.sendStreamingRequest(request: request) { _, data, _ in
            receivedData.value.append(data)
            return true
        }

        #expect(receivedData.value.count == 1)
        #expect(receivedData.value[0] == ["real"])
    }

    @Test("sendStreamingRequest onEvent stops when callback returns false")
    func streamingSSEStopOnFalse() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("event: first\ndata: a\n\nevent: second\ndata: b\n\nevent: third\ndata: c\n\n".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let eventCount = Box(0)
        try await client.sendStreamingRequest(request: request) { _, _, _ in
            eventCount.value += 1
            return eventCount.value < 2
        }

        #expect(eventCount.value == 2)
    }

    @Test("sendStreamingRequest onEvent handles trailing event without final newline")
    func streamingSSETrailingEvent() async throws {
        StreamingMockURLProtocol.setHandler { _ in
            (
                HTTPURLResponse(url: URL(string: "https://mock.test")!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!,
                [Data("data: first\n\ndata: trailing".utf8)]
            )
        }
        defer { StreamingMockURLProtocol.reset() }

        let client = HTTPClient.mockClient(protocols: [StreamingMockURLProtocol.self])
        let request = URLRequest(url: URL(string: "https://mock.test/sse")!)

        let receivedData = Box<[[String]]>([])
        try await client.sendStreamingRequest(request: request) { _, data, _ in
            receivedData.value.append(data)
            return true
        }

        #expect(receivedData.value.count == 2)
        #expect(receivedData.value[0] == ["first"])
        #expect(receivedData.value[1] == ["trailing"])
    }
}
