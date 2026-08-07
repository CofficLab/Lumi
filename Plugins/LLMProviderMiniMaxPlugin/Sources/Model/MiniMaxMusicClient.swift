import Foundation
import HttpKit
import LumiKernel

/// MiniMax 音乐生成客户端协议，便于测试时注入 mock 实现。
public protocol MiniMaxMusicClientProtocol: Sendable {
    func generate(
        prompt: String?,
        lyrics: String?,
        model: String,
        isInstrumental: Bool?,
        lyricsOptimizer: Bool?,
        audioUrl: String?,
        audioBase64: String?,
        coverFeatureId: String?,
        audioFormat: String?,
        sampleRate: Int?,
        bitrate: Int?,
        aigcWatermark: Bool?
    ) async throws -> MiniMaxMusicGeneratedAsset
}

/// 音乐生成最终交付物。
///
/// 包含 MiniMax 返回的音频 URL（24 小时有效）和音频元数据。
public struct MiniMaxMusicGeneratedAsset: Equatable, Sendable {
    /// 音频下载 URL（24 小时有效）。
    public let audioURL: URL
    /// 音频时长（毫秒）。
    public let durationMs: Int?
    /// 采样率（Hz）。
    public let sampleRate: Int?
    /// 声道数。
    public let channels: Int?
    /// 比特率（bps）。
    public let bitrate: Int?
    /// 文件大小（字节）。
    public let fileSize: Int?
    /// trace_id（用于问题排查）。
    public let traceId: String?
}

/// MiniMax 音乐生成客户端：单次 POST 请求，同步返回音频 URL。
///
/// - 可注入 `HTTPClient` 和 API Key provider，便于单测。
/// - 始终使用 `output_format: "url"` 获取下载链接。
/// - 失败时抛语义化 `MiniMaxMusicError`。
public final class MiniMaxMusicClient: MiniMaxMusicClientProtocol, @unchecked Sendable {
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
        prompt: String?,
        lyrics: String?,
        model: String,
        isInstrumental: Bool?,
        lyricsOptimizer: Bool?,
        audioUrl: String?,
        audioBase64: String?,
        coverFeatureId: String?,
        audioFormat: String?,
        sampleRate: Int?,
        bitrate: Int?,
        aigcWatermark: Bool?
    ) async throws -> MiniMaxMusicGeneratedAsset {
        if Task.isCancelled {
            throw MiniMaxMusicError.cancelled
        }

        let apiKey = try requireAPIKey()

        let url = try makeURL(path: MiniMaxMusicConstants.musicGenerationPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyJSONHeaders(&request, apiKey: apiKey)

        // 构建 audio_setting
        let audioSetting: MiniMaxMusicAudioSetting? = {
            guard audioFormat != nil || sampleRate != nil || bitrate != nil else { return nil }
            return MiniMaxMusicAudioSetting(
                sampleRate: sampleRate,
                bitrate: bitrate,
                format: audioFormat
            )
        }()

        let body = MiniMaxMusicGenerationRequest(
            model: model,
            prompt: prompt,
            lyrics: lyrics,
            stream: false,
            outputFormat: "url",
            audioSetting: audioSetting,
            aigcWatermark: aigcWatermark,
            lyricsOptimizer: lyricsOptimizer,
            isInstrumental: isInstrumental,
            audioUrl: audioUrl,
            audioBase64: audioBase64,
            coverFeatureId: coverFeatureId
        )

        let response: MiniMaxMusicGenerationResponse
        do {
            response = try await sendJSON(request: request, body: body, as: MiniMaxMusicGenerationResponse.self)
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error)
        }

        guard response.baseResp.isSuccess else {
            throw MiniMaxMusicError.apiError(
                code: response.baseResp.statusCode,
                message: response.baseResp.statusMessage
            )
        }

        // 解析音频 URL
        guard let audioString = response.data?.audio, !audioString.isEmpty else {
            throw MiniMaxMusicError.noAudioReturned
        }
        guard let audioURL = URL(string: audioString) else {
            throw MiniMaxMusicError.noAudioReturned
        }

        return MiniMaxMusicGeneratedAsset(
            audioURL: audioURL,
            durationMs: response.extraInfo?.musicDuration,
            sampleRate: response.extraInfo?.musicSampleRate,
            channels: response.extraInfo?.musicChannel,
            bitrate: response.extraInfo?.bitrate,
            fileSize: response.extraInfo?.musicSize,
            traceId: response.traceId
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

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: MiniMaxMusicConstants.baseURL + path) else {
            throw MiniMaxMusicError.apiError(
                code: -1,
                message: "Invalid MiniMax endpoint URL: \(path)"
            )
        }
        return url
    }

    private func applyJSONHeaders(_ request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(MiniMaxMusicConstants.jsonContentType, forHTTPHeaderField: "Content-Type")
        request.setValue(MiniMaxMusicConstants.jsonContentType, forHTTPHeaderField: "Accept")
    }

    private func requireAPIKey() throws -> String {
        guard let key = apiKeyProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            throw MiniMaxMusicError.missingAPIKey
        }
        return key
    }

    private func mapHTTPClientError(_ error: HTTPClientError) -> MiniMaxMusicError {
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
            return .apiError(code: -4, message: "Request failed: \(underlying.localizedDescription)")
        case .jsonSerializationFailed(let underlying):
            return .apiError(
                code: -5,
                message: "Failed to serialize request body: \(underlying.localizedDescription)"
            )
        }
    }
}
