import Foundation
import HttpKit
import LumiKernel

/// MiniMax 视频生成客户端协议，便于测试时注入 mock 实现。
public protocol MiniMaxVideoClientProtocol: Sendable {
    func generate(
        prompt: String,
        model: String,
        duration: Int?,
        resolution: String?,
        promptOptimizer: Bool?,
        fastPretreatment: Bool?,
        aigcWatermark: Bool?,
        shouldContinue: @escaping @Sendable () async -> Bool,
        pollInterval: UInt64
    ) async throws -> MiniMaxVideoGeneratedAsset
}

/// 视频生成最终交付物。
///
/// 注意：自此次重构起，客户端**不再下载**完整的 mp4 二进制，
/// 仅返回 MiniMax 给出的 24 小时有效的下载链接。
/// 这样可以避免 10–50 MB 的视频数据占用 LLM 上下文 token 与带宽。
public struct MiniMaxVideoGeneratedAsset: Equatable, Sendable {
    /// MiniMax 任务 ID。
    public let taskID: String
    /// MiniMax 文件 ID。
    public let fileID: String
    /// MiniMax 提供的下载链接（24 小时内有效）。
    public let downloadURL: URL
    /// 推荐用于下载的文件名（来自 MiniMax，或回退到默认值）。
    public let fileName: String
    /// MiniMax 报告的字节数（可能为 nil）。
    public let byteCount: Int64?
    /// 下载链接的 MIME 类型（一般 `video/mp4`）。
    public let mimeType: String
}

/// MiniMax 视频生成客户端：submit → poll → retrieveFile 三步交付链。
///
/// - 可注入 `HTTPClient` 和 API Key provider，便于单测。
/// - 每个步骤都允许 `shouldContinue()` 检查（基于 `Task.isCancelled`）。
/// - 失败时抛语义化 `MiniMaxVideoError`。
public final class MiniMaxVideoClient: MiniMaxVideoClientProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let network: (any NetworkProviding)?
    private let apiKeyProvider: @Sendable () -> String?

    public init(
        httpClient: HTTPClient = HTTPClient(
            timeoutIntervalForRequest: 60,
            timeoutIntervalForResource: 300
        ),
        apiKeyProvider: @Sendable @escaping () -> String?
    ) {
        self.httpClient = httpClient
        self.network = nil
        self.apiKeyProvider = apiKeyProvider
    }

    @MainActor
    public init(network: any NetworkProviding, apiKeyProvider: @Sendable @escaping () -> String?) {
        self.httpClient = HTTPClient(timeoutIntervalForRequest: 60, timeoutIntervalForResource: 300)
        self.network = network
        self.apiKeyProvider = apiKeyProvider
    }

    public func generate(
        prompt: String,
        model: String,
        duration: Int?,
        resolution: String?,
        promptOptimizer: Bool?,
        fastPretreatment: Bool?,
        aigcWatermark: Bool?,
        shouldContinue: @escaping @Sendable () async -> Bool,
        pollInterval: UInt64 = MiniMaxVideoConstants.pollInterval
    ) async throws -> MiniMaxVideoGeneratedAsset {
        try await checkContinue(shouldContinue)
        let apiKey = try requireAPIKey()
        let taskID = try await submit(
            prompt: prompt,
            model: model,
            duration: duration,
            resolution: resolution,
            promptOptimizer: promptOptimizer,
            fastPretreatment: fastPretreatment,
            aigcWatermark: aigcWatermark,
            apiKey: apiKey,
            shouldContinue: shouldContinue
        )
        let fileID = try await poll(
            taskID: taskID,
            apiKey: apiKey,
            pollInterval: pollInterval,
            shouldContinue: shouldContinue
        )
        let fileInfo = try await retrieveFile(
            fileID: fileID,
            apiKey: apiKey,
            shouldContinue: shouldContinue
        )
        // 注意：不再调用 download(...) 直接拉取 mp4 二进制（10–50MB）。
        // MiniMax 提供的 downloadURL 在 24 小时内有效，工具会把链接回传给调用方。
        return MiniMaxVideoGeneratedAsset(
            taskID: taskID,
            fileID: fileID,
            downloadURL: fileInfo.downloadURL,
            fileName: fileInfo.fileName,
            byteCount: fileInfo.byteCount,
            mimeType: MiniMaxVideoConstants.videoMimeType
        )
    }

    // MARK: - Step 1: Submit

    private func submit(
        prompt: String,
        model: String,
        duration: Int?,
        resolution: String?,
        promptOptimizer: Bool?,
        fastPretreatment: Bool?,
        aigcWatermark: Bool?,
        apiKey: String,
        shouldContinue: @escaping @Sendable () async -> Bool
    ) async throws -> String {
        try await checkContinue(shouldContinue)
        let url = try makeURL(path: MiniMaxVideoConstants.createTaskPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyJSONHeaders(&request, apiKey: apiKey)

        let body = MiniMaxVideoTaskCreateRequest(
            model: model,
            prompt: prompt,
            duration: duration,
            resolution: resolution,
            promptOptimizer: promptOptimizer,
            fastPretreatment: fastPretreatment,
            aigcWatermark: aigcWatermark
        )

        let response: MiniMaxVideoTaskCreateResponse
        do {
            response = try await sendJSON(request: request, body: body, as: MiniMaxVideoTaskCreateResponse.self)
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error)
        }

        guard response.baseResp.isSuccess else {
            throw MiniMaxVideoError.apiError(
                code: response.baseResp.statusCode,
                message: response.baseResp.statusMessage
            )
        }
        guard let taskID = response.taskId, !taskID.isEmpty else {
            throw MiniMaxVideoError.apiError(code: -1, message: "MiniMax returned no task_id")
        }
        return taskID
    }

    // MARK: - Step 2: Poll

    private func poll(
        taskID: String,
        apiKey: String,
        pollInterval: UInt64,
        shouldContinue: @escaping @Sendable () async -> Bool
    ) async throws -> String {
        let startedAt = Date()
        let url = try makeURL(path: MiniMaxVideoConstants.queryTaskPath)

        while true {
            try await checkContinue(shouldContinue)

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed > MiniMaxVideoConstants.maxPollingDuration {
                throw MiniMaxVideoError.pollingTimeout
            }

            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "task_id", value: taskID)]
            guard let queryURL = components.url else {
                throw MiniMaxVideoError.apiError(code: -1, message: "Failed to build query URL")
            }

            var request = URLRequest(url: queryURL)
            request.httpMethod = "GET"
            applyJSONHeaders(&request, apiKey: apiKey)

            let response: MiniMaxVideoTaskQueryResponse
            do {
                response = try await sendJSON(request: request, as: MiniMaxVideoTaskQueryResponse.self)
            } catch let error as HTTPClientError {
                throw mapHTTPClientError(error)
            }

            guard response.baseResp.isSuccess else {
                throw MiniMaxVideoError.apiError(
                    code: response.baseResp.statusCode,
                    message: response.baseResp.statusMessage
                )
            }

            if response.isSuccess, let fileID = response.fileId, !fileID.isEmpty {
                return fileID
            }
            if response.isFailure {
                let message = response.errorMessage ?? response.baseResp.statusMessage
                throw MiniMaxVideoError.taskFailed(message: message)
            }

            do {
                try await Task.sleep(nanoseconds: pollInterval)
            } catch is CancellationError {
                throw MiniMaxVideoError.cancelled
            }
        }
    }
    // MARK: - Step 3: Retrieve File

    private func retrieveFile(
        fileID: String,
        apiKey: String,
        shouldContinue: @escaping @Sendable () async -> Bool
    ) async throws -> RetrievedFile {
        try await checkContinue(shouldContinue)

        let url = try makeURL(path: MiniMaxVideoConstants.retrieveFilePath)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "file_id", value: fileID)]
        guard let queryURL = components.url else {
            throw MiniMaxVideoError.apiError(code: -1, message: "Failed to build file retrieve URL")
        }

        var request = URLRequest(url: queryURL)
        request.httpMethod = "GET"
        applyJSONHeaders(&request, apiKey: apiKey)

        let response: MiniMaxFileRetrieveResponse
        do {
            response = try await sendJSON(request: request, as: MiniMaxFileRetrieveResponse.self)
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error)
        }

        guard response.baseResp.isSuccess else {
            throw MiniMaxVideoError.apiError(
                code: response.baseResp.statusCode,
                message: response.baseResp.statusMessage
            )
        }
        guard let downloadURL = response.resolveDownloadURL() else {
            throw MiniMaxVideoError.missingDownloadURL
        }
        return RetrievedFile(
            downloadURL: downloadURL,
            fileName: response.preferredFilename(),
            byteCount: response.byteCount()
        )
    }

    // MARK: - Helpers

    private func sendJSON<Body: Encodable, Response: Decodable>(
        request: URLRequest,
        body: Body,
        as: Response.Type
    ) async throws -> Response {
        var request = request
        request.httpBody = try JSONEncoder().encode(body)
        return try await sendJSON(request: request, as: Response.self)
    }

    private func sendJSON<Response: Decodable>(request: URLRequest, as: Response.Type) async throws -> Response {
        let data = try await sendData(request: request)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(underlying: error)
        }
    }

    private func sendData(request: URLRequest) async throws -> Data {
        guard let url = request.url else { throw HTTPClientError.invalidResponse }
        guard let network else { return try await httpClient.sendRequest(request: request) }
        let response = try await network.request(HTTPRequest(
            url: url,
            method: HTTPMethod(rawValue: request.httpMethod ?? "GET") ?? .get,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: request.timeoutInterval
        ))
        return response.body
    }

    private struct RetrievedFile {
        let downloadURL: URL
        let fileName: String
        let byteCount: Int64?
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: MiniMaxVideoConstants.baseURL + path) else {
            throw MiniMaxVideoError.apiError(
                code: -1,
                message: "Invalid MiniMax endpoint URL: \(path)"
            )
        }
        return url
    }

    private func applyJSONHeaders(_ request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(MiniMaxVideoConstants.jsonContentType, forHTTPHeaderField: "Content-Type")
        request.setValue(MiniMaxVideoConstants.jsonContentType, forHTTPHeaderField: "Accept")
    }

    private func requireAPIKey() throws -> String {
        guard let key = apiKeyProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            throw MiniMaxVideoError.missingAPIKey
        }
        return key
    }

    private func mapHTTPClientError(_ error: HTTPClientError) -> MiniMaxVideoError {
        switch error {
        case .httpError(let statusCode, let message):
            return .apiError(code: statusCode, message: "HTTP \(statusCode): \(message)")
        case .decodingFailed(let underlying):
            return .apiError(
                code: -2,
                message: "Failed to decode MiniMax response: \(underlying.localizedDescription)"
            )
        case .invalidResponse:
            return .apiError(code: -3, message: "MiniMax returned an invalid response")
        case .requestFailed(let underlying):
            return .downloadFailed(message: underlying.localizedDescription)
        case .jsonSerializationFailed(let underlying):
            return .apiError(
                code: -4,
                message: "Failed to serialize request body: \(underlying.localizedDescription)"
            )
        }
    }

    private func checkContinue(
        _ shouldContinue: @escaping @Sendable () async -> Bool
    ) async throws {
        if Task.isCancelled {
            throw MiniMaxVideoError.cancelled
        }
        if await shouldContinue() == false {
            throw MiniMaxVideoError.cancelled
        }
    }
}
