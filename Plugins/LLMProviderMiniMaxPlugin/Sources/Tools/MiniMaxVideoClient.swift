import Foundation
import HttpKit
import LumiCoreKit

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
public struct MiniMaxVideoGeneratedAsset: Equatable, Sendable {
    public let videoData: Data
    public let mimeType: String
    public let fileName: String
    public let byteCount: Int64

    public var base64Data: String {
        videoData.base64EncodedString()
    }
}

/// MiniMax 视频生成客户端：submit → poll → retrieveFile → download 四步交付链。
///
/// - 可注入 `HTTPClient` 和 API Key provider，便于单测。
/// - 每个步骤都允许 `shouldContinue()` 检查（基于 `Task.isCancelled`）。
/// - 失败时抛语义化 `MiniMaxVideoError`。
public final class MiniMaxVideoClient: MiniMaxVideoClientProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let apiKeyProvider: @Sendable () -> String?

    public init(
        httpClient: HTTPClient = HTTPClient(
            timeoutIntervalForRequest: 60,
            timeoutIntervalForResource: 300
        ),
        apiKeyProvider: @Sendable @escaping () -> String?
    ) {
        self.httpClient = httpClient
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
        let videoData = try await download(
            downloadURL: fileInfo.downloadURL,
            shouldContinue: shouldContinue
        )
        return MiniMaxVideoGeneratedAsset(
            videoData: videoData,
            mimeType: MiniMaxVideoConstants.videoMimeType,
            fileName: fileInfo.fileName,
            byteCount: Int64(videoData.count)
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
            response = try await httpClient.sendEncodableDecodableRequest(
                request: request,
                body: body,
                as: MiniMaxVideoTaskCreateResponse.self
            )
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
                response = try await httpClient.sendDecodableRequest(
                    request: request,
                    as: MiniMaxVideoTaskQueryResponse.self
                )
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
            response = try await httpClient.sendDecodableRequest(
                request: request,
                as: MiniMaxFileRetrieveResponse.self
            )
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

    // MARK: - Step 4: Download

    private func download(
        downloadURL: URL,
        shouldContinue: @escaping @Sendable () async -> Bool
    ) async throws -> Data {
        try await checkContinue(shouldContinue)

        var request = URLRequest(url: downloadURL)
        request.httpMethod = "GET"
        request.setValue(MiniMaxVideoConstants.videoMimeType, forHTTPHeaderField: "Accept")

        let data: Data
        do {
            data = try await httpClient.sendRequest(request: request)
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error)
        }

        guard data.count >= 1024 else {
            throw MiniMaxVideoError.downloadFailed(
                message: "Downloaded payload too small (\(data.count) bytes)"
            )
        }
        return data
    }

    // MARK: - Helpers

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
