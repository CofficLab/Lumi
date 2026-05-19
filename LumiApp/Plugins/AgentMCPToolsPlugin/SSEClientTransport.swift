import Foundation
import HttpKit
import Logging
import MagicKit
import MCP

/// A Transport that communicates via Server-Sent Events (SSE)
///
/// 使用 HttpKit 的 `sendStreamingRequest` 处理 SSE 连接，
/// 使用 `sendDataRequestWithResponse` 发送消息。
actor SSEClientTransport: Transport, SuperLog {
    nonisolated static let emoji = "📡"
    nonisolated static let verbose: Bool = false
    nonisolated let logger: Logging.Logger
    let url: URL
    let headers: [String: String]

    private let messageStream: AsyncThrowingStream<Data, Error>
    private let messageContinuation: AsyncThrowingStream<Data, Error>.Continuation

    private let client: HTTPClient
    nonisolated(unsafe) private var endpointURL: URL?

    init(url: URL, headers: [String: String] = [:], logger: Logging.Logger? = nil) {
        self.url = url
        self.headers = headers
        self.logger = logger ?? Logging.Logger(label: "Lumi.SSEClientTransport")
        self.client = HTTPClient()

        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    func connect() async throws {
        if Self.verbose {
            if AgentMCPToolsPlugin.verbose {
                AgentMCPToolsPlugin.logger.info("\(Self.t)Connecting to SSE: \(self.url.absoluteString)")
            }
        }

        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 300

        try await client.sendStreamingRequest(request: request) { event, data, _ in
            // 处理 'endpoint' 事件，设置 POST URL
            if event == "endpoint" {
                let endpointString = data.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if let endpoint = URL(string: endpointString, relativeTo: self.url) {
                    self.endpointURL = endpoint
                    if Self.verbose {
                        if AgentMCPToolsPlugin.verbose {
                            AgentMCPToolsPlugin.logger.info("\(Self.t)SSE Endpoint received: \(endpoint.absoluteString)")
                        }
                    }
                }
                return true
            }

            // 处理 'message' 事件或默认事件
            if event == "message" || event == nil {
                let fullData = data.joined(separator: "\n")
                if let dataBytes = fullData.data(using: .utf8) {
                    self.messageContinuation.yield(dataBytes)
                }
            }

            return true
        }
    }

    private func handleMessage(event: String?, data: String, id: String?) {
        // Handle 'endpoint' event to set the POST URL
        if event == "endpoint" {
            let endpointString = data.trimmingCharacters(in: .whitespacesAndNewlines)

            if let endpoint = URL(string: endpointString, relativeTo: self.url) {
                self.endpointURL = endpoint
                if Self.verbose {
                    if AgentMCPToolsPlugin.verbose {
                        AgentMCPToolsPlugin.logger.info("\(Self.t)SSE Endpoint received: \(endpoint.absoluteString)")
                    }
                }
            } else {
                if AgentMCPToolsPlugin.verbose {
                    AgentMCPToolsPlugin.logger.error("\(Self.t)Invalid endpoint URL: \(endpointString)")
                }
            }
            return
        }

        if event == "message" || event == nil {
            if let dataBytes = data.data(using: .utf8) {
                self.messageContinuation.yield(dataBytes)
            }
        }
    }

    func disconnect() async {
        messageContinuation.finish()
    }

    func send(_ data: Data) async throws {
        guard let postURL = endpointURL else {
            throw NSError(domain: "SSEClientTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endpoint URL not established. Waiting for 'endpoint' event."])
        }

        var request = URLRequest(url: postURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        _ = try await client.sendDataRequestWithResponse(request: request, body: data)
    }

    nonisolated func receive() -> AsyncThrowingStream<Data, Error> {
        return messageStream
    }
}
