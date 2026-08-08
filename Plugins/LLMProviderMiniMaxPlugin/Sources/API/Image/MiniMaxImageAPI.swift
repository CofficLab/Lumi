import Foundation
import HttpKit
import LumiKernel

/// Image generation result asset.
public struct MiniMaxImageGeneratedAsset: Equatable, Sendable {
    public let taskID: String?
    public let imageURLs: [URL]
    public let successCount: Int
    public let failedCount: Int
}

// MARK: - Protocol

public protocol MiniMaxImageAPIProtocol: Sendable {
    func generate(
        prompt: String,
        model: String,
        subjectReference: [MiniMaxImageSubjectReference]?,
        styleType: String?,
        styleWeight: Float?,
        aspectRatio: String?,
        width: Int?,
        height: Int?,
        n: Int?,
        promptOptimizer: Bool?,
        aigcWatermark: Bool?
    ) async throws -> MiniMaxImageGeneratedAsset
}

// MARK: - Implementation

private struct DecodingErrorWrapper: LocalizedError, CustomStringConvertible {
    let underlying: Error
    let responseBodyPreview: String
    var description: String {
        "\(underlying.localizedDescription)\nResponse body (first 500 chars): \(responseBodyPreview)"
    }
    var errorDescription: String? { description }
}

public final class MiniMaxImageAPI: MiniMaxImageAPIProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let network: (any NetworkProviding)?
    private let apiKeyProvider: @Sendable () -> String?

    public init(
        httpClient: HTTPClient = HTTPClient(timeoutIntervalForRequest: 60, timeoutIntervalForResource: 120),
        apiKeyProvider: @Sendable @escaping () -> String?
    ) {
        self.httpClient = httpClient
        self.network = nil
        self.apiKeyProvider = apiKeyProvider
    }

    @MainActor
    public init(network: any NetworkProviding, apiKeyProvider: @Sendable @escaping () -> String?) {
        self.httpClient = HTTPClient(timeoutIntervalForRequest: 60, timeoutIntervalForResource: 120)
        self.network = network
        self.apiKeyProvider = apiKeyProvider
    }

    public func generate(
        prompt: String,
        model: String,
        subjectReference: [MiniMaxImageSubjectReference]?,
        styleType: String?,
        styleWeight: Float?,
        aspectRatio: String?,
        width: Int?,
        height: Int?,
        n: Int?,
        promptOptimizer: Bool?,
        aigcWatermark: Bool?
    ) async throws -> MiniMaxImageGeneratedAsset {
        if Task.isCancelled { throw MiniMaxImageError.cancelled }
        let apiKey = try requireAPIKey()
        let url = try makeURL(path: MiniMaxImageConstants.imageGenerationPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyJSONHeaders(&request, apiKey: apiKey)

        let style: MiniMaxImageStyleObject? = {
            guard model == MiniMaxImageModel.image01Live.rawValue, let styleType else { return nil }
            return MiniMaxImageStyleObject(styleType: styleType, styleWeight: styleWeight)
        }()

        let body = MiniMaxImageGenerationRequest(
            model: model, prompt: prompt, subjectReference: subjectReference, style: style,
            aspectRatio: aspectRatio, width: width, height: height, responseFormat: "url",
            seed: nil, n: n, promptOptimizer: promptOptimizer, aigcWatermark: aigcWatermark
        )

        let response: MiniMaxImageGenerationResponse
        do {
            response = try await sendJSON(request: request, body: body, as: MiniMaxImageGenerationResponse.self)
        } catch let error as HTTPClientError {
            throw mapHTTPClientError(error)
        }

        guard response.baseResp.isSuccess else {
            throw MiniMaxImageError.apiError(code: response.baseResp.statusCode, message: response.baseResp.statusMessage)
        }

        let urlStrings = response.data?.imageUrls ?? []
        let urls = urlStrings.compactMap { URL(string: $0) }
        guard !urls.isEmpty else { throw MiniMaxImageError.noImagesReturned }

        let successCount = response.metadata?.successCount.flatMap { Int($0) } ?? urls.count
        let failedCount = response.metadata?.failedCount.flatMap { Int($0) } ?? 0
        return MiniMaxImageGeneratedAsset(taskID: response.id, imageURLs: urls, successCount: successCount, failedCount: failedCount)
    }

    private func sendJSON<Body: Encodable, Response: Decodable>(
        request: URLRequest, body: Body, as: Response.Type
    ) async throws -> Response {
        var request = request
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await sendData(request: request)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-UTF8 data, \(data.count) bytes>"
            throw HTTPClientError.decodingFailed(underlying: DecodingErrorWrapper(underlying: error, responseBodyPreview: bodyPreview))
        }
    }

    private func sendData(request: URLRequest) async throws -> Data {
        guard let url = request.url else { throw HTTPClientError.invalidResponse }
        guard let network else { return try await httpClient.sendRequest(request: request) }
        let response = try await network.request(HTTPRequest(
            url: url, method: HTTPMethod(rawValue: request.httpMethod ?? "GET") ?? .get,
            headers: request.allHTTPHeaderFields ?? [:], body: request.httpBody, timeout: request.timeoutInterval
        ))
        return response.body
    }

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: MiniMaxImageConstants.baseURL + path) else {
            throw MiniMaxImageError.apiError(code: -1, message: "Invalid MiniMax endpoint URL: \(path)")
        }
        return url
    }

    private func applyJSONHeaders(_ request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(MiniMaxImageConstants.jsonContentType, forHTTPHeaderField: "Content-Type")
        request.setValue(MiniMaxImageConstants.jsonContentType, forHTTPHeaderField: "Accept")
    }

    private func requireAPIKey() throws -> String {
        guard let key = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw MiniMaxImageError.missingAPIKey
        }
        return key
    }

    private func mapHTTPClientError(_ error: HTTPClientError) -> MiniMaxImageError {
        switch error {
        case .httpError(let statusCode, let message):
            return .apiError(code: statusCode, message: "HTTP \(statusCode): \(message)")
        case .decodingFailed(let underlying):
            return .apiError(code: -2, message: "Failed to decode MiniMax response: \(underlying.localizedDescription)")
        case .invalidResponse:
            return .apiError(code: -3, message: "MiniMax returned an invalid response")
        case .requestFailed(let underlying):
            return .apiError(code: -4, message: "Request failed: \(underlying.localizedDescription)")
        case .jsonSerializationFailed(let underlying):
            return .apiError(code: -5, message: "Failed to serialize request body: \(underlying.localizedDescription)")
        }
    }
}
