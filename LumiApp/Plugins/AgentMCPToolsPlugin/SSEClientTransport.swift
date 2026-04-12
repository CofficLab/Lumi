import Foundation
import Logging
import MagicKit
import MCP

/// A Transport that communicates via Server-Sent Events (SSE)
actor SSEClientTransport: Transport, SuperLog {
    nonisolated static let emoji = "📡"
    nonisolated static let verbose: Bool = false    nonisolated let logger: Logging.Logger
    let url: URL
    let headers: [String: String]

    private let messageStream: AsyncThrowingStream<Data, Error>
    private let messageContinuation: AsyncThrowingStream<Data, Error>.Continuation

    private var session: URLSession
    private var endpointURL: URL? // The URL to POST messages to
    private var task: URLSessionDataTask?

    init(url: URL, headers: [String: String] = [:], logger: Logging.Logger? = nil) {
        self.url = url
        self.headers = headers
        self.logger = logger ?? Logging.Logger(label: "Lumi.SSEClientTransport")
        self.session = URLSession(configuration: .default)

        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.messageStream = AsyncThrowingStream { continuation = $0 }
        self.messageContinuation = continuation
    }

    func connect() async throws {
        AgentMCPToolsPlugin.logger.info("\(Self.t)Connecting to SSE: \(self.url.absoluteString)")

        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 300 // Long timeout for SSE

        // Start streaming
        Task {
            do {
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200 ... 299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    throw NSError(domain: "SSEClientTransport", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid status code: \(statusCode)"])
                }

                AgentMCPToolsPlugin.logger.info("\(Self.t)SSE Connected")

                var currentEvent: String?
                var currentData: String = ""
                var currentId: String?

                for try await line in bytes.lines {
                    if line.isEmpty {
                        // End of event dispatch
                        if !currentData.isEmpty {
                            self.handleMessage(event: currentEvent, data: currentData, id: currentId)
                        }

                        // Reset state
                        currentEvent = nil
                        currentData = ""
                        currentId = nil
                        continue
                    }

                    if line.hasPrefix("event:") {
                        currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        let dataLine = String(line.dropFirst(5))
                        // According to spec, if data starts with space, remove it
                        let cleanData = dataLine.hasPrefix(" ") ? String(dataLine.dropFirst()) : dataLine

                        if currentData.isEmpty {
                            currentData = cleanData
                        } else {
                            currentData += "\n" + cleanData
                        }
                    } else if line.hasPrefix("id:") {
                        currentId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix(":") {
                        // Comment, ignore
                    }
                }

                // Stream ended
                AgentMCPToolsPlugin.logger.info("\(Self.t)SSE Stream ended")
                self.messageContinuation.finish()

            } catch {
                AgentMCPToolsPlugin.logger.error("\(Self.t)SSE Error: \(error.localizedDescription)")
                self.messageContinuation.finish(throwing: error)
            }
        }
    }

    private func handleMessage(event: String?, data: String, id: String?) {
        // Handle 'endpoint' event to set the POST URL
        if event == "endpoint" {
            let endpointString = data.trimmingCharacters(in: .whitespacesAndNewlines)

            if let endpoint = URL(string: endpointString, relativeTo: self.url) {
                self.endpointURL = endpoint
                AgentMCPToolsPlugin.logger.info("\(Self.t)SSE Endpoint received: \(endpoint.absoluteString)")
            } else {
                AgentMCPToolsPlugin.logger.error("\(Self.t)Invalid endpoint URL: \(endpointString)")
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
        session.invalidateAndCancel()
    }

    func send(_ data: Data) async throws {
        guard let postURL = endpointURL else {
            throw NSError(domain: "SSEClientTransport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endpoint URL not established. Waiting for 'endpoint' event."])
        }

        var request = URLRequest(url: postURL)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200 ... 299).contains(httpResponse.statusCode) {
            throw NSError(domain: "SSEClientTransport", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
        }
    }

    nonisolated func receive() -> AsyncThrowingStream<Data, Error> {
        return messageStream
    }
}

