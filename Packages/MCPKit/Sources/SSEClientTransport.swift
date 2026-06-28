import Foundation
import SuperLogKit
import HttpKit
import Logging
import MCP

public actor SSEClientTransport: Transport, SuperLog {
    public let url: URL
    public let headers: [String: String]

    public let logger: Logging.Logger
    private let messageStream: AsyncThrowingStream<Data, Error>
    private let messageContinuation: AsyncThrowingStream<Data, Error>.Continuation

    private let client: HTTPClient
    nonisolated(unsafe) private var endpointURL: URL?

    public init(url: URL, headers: [String: String] = [:], logger: Logging.Logger? = nil) {
        self.url = url
        self.headers = headers
        self.logger = logger ?? Logging.Logger(label: "Lumi.MCPKit.SSEClientTransport")
        self.client = HTTPClient()

        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    public func connect() async throws {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 300

        try await client.sendStreamingRequest(request: request) { event, data, _ in
            if event == "endpoint" {
                let endpointString = data.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if let endpoint = URL(string: endpointString, relativeTo: self.url) {
                    self.endpointURL = endpoint
                } else {
                    self.logger.error("\(Self.t)Invalid MCP SSE endpoint URL: \(endpointString)")
                }
                return true
            }

            if event == "message" || event == nil {
                let fullData = data.joined(separator: "\n")
                if let dataBytes = fullData.data(using: .utf8) {
                    self.messageContinuation.yield(dataBytes)
                }
            }

            return true
        }
    }

    public func disconnect() async {
        messageContinuation.finish()
    }

    public func send(_ data: Data) async throws {
        guard let postURL = endpointURL else {
            throw NSError(
                domain: "SSEClientTransport",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Endpoint URL not established. Waiting for 'endpoint' event."]
            )
        }

        var request = URLRequest(url: postURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        _ = try await client.sendDataRequestWithResponse(request: request, body: data)
    }

    nonisolated public func receive() -> AsyncThrowingStream<Data, Error> {
        messageStream
    }
}
