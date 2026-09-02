import CryptoKit
import Foundation
import KernelCore
import KitAgentTool
import KitAppStorePromo
import KitLocalization
import KitSuperLog
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderNetwork
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
import os
import KitSuperLog
enum AppStoreConnectClientError: LocalizedError {
    case missingCredentials
    case invalidPrivateKey
    case invalidURL
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return AppStoreConnectLocalization.string("App Store Connect credentials are incomplete.")
        case .invalidPrivateKey:
            return AppStoreConnectLocalization.string("The private key could not be parsed. Use the .p8 key downloaded from App Store Connect.")
        case .invalidURL:
            return AppStoreConnectLocalization.string("The App Store Connect URL is invalid.")
        case .requestFailed(let message):
            return message
        case .invalidResponse:
            return AppStoreConnectLocalization.string("App Store Connect returned an invalid response.")
        }
    }
}

final class ConnectClient: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🔗"
    nonisolated static let verbose = false
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect.client")

    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let credentialsProvider: @Sendable () -> AppStoreConnectCredentials
    private let network: (any NetworkProviding)?
    private let cache: ConnectAPICache
    var fetchPolicy: ConnectFetchPolicy = .cacheFirst

    init(
        credentialsProvider: @escaping @Sendable () -> AppStoreConnectCredentials,
        network: any NetworkProviding,
        cache: ConnectAPICache = .shared
    ) {
        self.credentialsProvider = credentialsProvider
        self.network = network
        self.cache = cache
    }

    /// Creates an unconfigured client for view-model construction before plugin
    /// boot. Requests fail locally until Kernel network is injected.
    init(
        credentialsProvider: @escaping @Sendable () -> AppStoreConnectCredentials,
        cache: ConnectAPICache = .shared
    ) {
        self.credentialsProvider = credentialsProvider
        self.network = nil
        self.cache = cache
    }

    func invalidateCache() {
        cache.clear()
    }

    func pruneStaleVersionCache(keepingVersionIDs: Set<String>) {
        cache.pruneVersions(keepingVersionIDs: keepingVersionIDs, accountKey: makeAccountKey())
    }

    func testConnection() async throws {
        _ = try await listApps(limit: 1)
    }

    func listApps(search: String? = nil, limit: Int = 100) async throws -> [AppStoreApp] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sort", value: "name"),
            URLQueryItem(name: "fields[apps]", value: "name,bundleId,sku,primaryLocale,appStoreIcon"),
            URLQueryItem(name: "include", value: "appStoreIcon"),
            URLQueryItem(name: "fields[buildIcons]", value: "iconAsset")
        ]

        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "filter[name]", value: search))
        }

        let response: AppStoreConnectListResponseWithIncluded<AppStoreApp, BuildIconResource> = try await request(
            path: "/v1/apps",
            queryItems: query
        )
        let iconsByID = Dictionary(
            (response.included ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return response.data.map { app in
            app.withIconURL(app.appStoreIconID.flatMap { iconsByID[$0]?.iconAsset?.url(width: 64, height: 64) })
        }
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AppStoreConnectClientError.invalidURL
        }
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw AppStoreConnectClientError.invalidURL
        }

        let cacheKey = makeCacheKey(method: method, path: path, queryItems: queryItems)
        if method == "GET", let cached = cache.get(logicalKey: cacheKey, fetchPolicy: fetchPolicy) {
            return try decodeResponse(cached)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try makeJWT())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, statusCode) = try await send(request)

        guard (200 ..< 300).contains(statusCode) else {
            throw AppStoreConnectClientError.requestFailed(apiErrorMessage(from: data, statusCode: statusCode))
        }

        if method == "GET" {
            cache.set(logicalKey: cacheKey, method: method, path: path, data: data)
        } else {
            cache.invalidateAfterMutation(
                method: method,
                path: path,
                body: body,
                accountKey: makeAccountKey()
            )
        }

        return try decodeResponse(data)
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    /// 发送不期望响应体的请求（如 DELETE 或返回 204 的 PATCH relationships）。
    func requestWithoutResponse(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AppStoreConnectClientError.invalidURL
        }
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw AppStoreConnectClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try makeJWT())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, statusCode) = try await send(request)

        guard (200 ..< 300).contains(statusCode) else {
            throw AppStoreConnectClientError.requestFailed(apiErrorMessage(from: data, statusCode: statusCode))
        }

        cache.invalidateAfterMutation(
            method: method,
            path: path,
            body: body,
            accountKey: makeAccountKey()
        )
    }

    func makeCacheKey(method: String, path: String, queryItems: [URLQueryItem]) -> String {
        "\(makeAccountKey())|\(method)|\(path)|\(sortedQueryString(queryItems))"
    }

    func makeAccountKey() -> String {
        let credentials = credentialsProvider()
        return "\(credentials.issuerID)|\(credentials.keyID)"
    }

    private func sortedQueryString(_ queryItems: [URLQueryItem]) -> String {
        queryItems
            .sorted { $0.name == $1.name ? ($0.value ?? "") < ($1.value ?? "") : $0.name < $1.name }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
    }

    private func apiErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorResponse = try? JSONDecoder().decode(AppStoreConnectErrorResponse.self, from: data),
           let first = errorResponse.errors.first {
            return [first.title, first.detail]
                .compactMap { $0 }
                .joined(separator: ": ")
        }
        return AppStoreConnectLocalization.string("App Store Connect request failed with HTTP %d.", statusCode)
    }

    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        guard let url = request.url else {
            throw AppStoreConnectClientError.invalidURL
        }

        if let network {
            let kernelRequest = HTTPRequest(
                url: url,
                method: HTTPMethod(rawValue: request.httpMethod ?? "GET") ?? .get,
                headers: request.allHTTPHeaderFields ?? [:],
                body: request.httpBody,
                timeout: request.timeoutInterval
            )
            do {
                let response = try await network.request(kernelRequest)
                return (response.body, response.statusCode)
            } catch let error as HTTPNetworkError {
                // NetworkProviding reports non-2xx responses as errors. Preserve
                // the response payload so App Store Connect API errors keep their
                // existing user-facing messages.
                if let statusCode = error.statusCode {
                    return (error.body ?? Data(), statusCode)
                }
                throw error
            }
        }

        throw AppStoreConnectClientError.requestFailed(
            AppStoreConnectLocalization.string("Network service is unavailable.")
        )
    }

    private func makeJWT() throws -> String {
        let credentials = credentialsProvider()
        guard credentials.isComplete else {
            throw AppStoreConnectClientError.missingCredentials
        }

        let now = Int(Date().timeIntervalSince1970)
        let header: [String: Any] = [
            "alg": "ES256",
            "kid": credentials.keyID,
            "typ": "JWT"
        ]
        let payload: [String: Any] = [
            "iss": credentials.issuerID,
            "iat": now,
            "exp": now + 20 * 60,
            "aud": "appstoreconnect-v1"
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let signingInput = "\(headerData.base64URLEncodedString()).\(payloadData.base64URLEncodedString())"

        guard let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: credentials.privateKey) else {
            throw AppStoreConnectClientError.invalidPrivateKey
        }

        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(signature.rawRepresentation.base64URLEncodedString())"
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
