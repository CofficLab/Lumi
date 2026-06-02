import CryptoKit
import Foundation

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

final class AppStoreConnectClient: @unchecked Sendable {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let credentialsProvider: @Sendable () -> AppStoreConnectCredentials
    private let session: URLSession

    init(
        credentialsProvider: @escaping @Sendable () -> AppStoreConnectCredentials,
        session: URLSession = .shared
    ) {
        self.credentialsProvider = credentialsProvider
        self.session = session
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

    func listVersions(appID: String) async throws -> [AppStoreVersion] {
        let query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(
                name: "fields[appStoreVersions]",
                value: "platform,versionString,appStoreState,appVersionState,createdDate"
            )
        ]
        let response: AppStoreConnectListResponse<AppStoreVersion> = try await request(
            path: "/v1/apps/\(appID)/appStoreVersions",
            queryItems: query
        )
        return response.data.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
    }

    func listLocalizations(versionID: String) async throws -> [AppStoreVersionLocalization] {
        let query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(
                name: "fields[appStoreVersionLocalizations]",
                value: "locale,promotionalText,description,keywords,whatsNew,supportUrl,marketingUrl"
            )
        ]
        let response: AppStoreConnectListResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations",
            queryItems: query
        )
        return response.data
    }

    func updateLocalization(_ localization: AppStoreVersionLocalization) async throws -> AppStoreVersionLocalization {
        let payload: [String: Any] = [
            "data": [
                "type": "appStoreVersionLocalizations",
                "id": localization.id,
                "attributes": [
                    "promotionalText": localization.promotionalText,
                    "description": localization.description,
                    "keywords": localization.keywords,
                    "whatsNew": localization.whatsNew,
                    "supportUrl": localization.supportURL,
                    "marketingUrl": localization.marketingURL
                ]
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: AppStoreConnectSingleResponse<AppStoreVersionLocalization> = try await request(
            path: "/v1/appStoreVersionLocalizations/\(localization.id)",
            method: "PATCH",
            body: body
        )
        return response.data
    }

    func listScreenshotSets(localizationID: String) async throws -> [ScreenshotSet] {
        let query = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "fields[appScreenshotSets]", value: "screenshotDisplayType")
        ]
        let response: AppStoreConnectListResponse<ScreenshotSet> = try await request(
            path: "/v1/appStoreVersionLocalizations/\(localizationID)/appScreenshotSets",
            queryItems: query
        )
        return response.data
    }

    func createScreenshotSet(localizationID: String, displayType: String) async throws -> ScreenshotSet {
        let payload: [String: Any] = [
            "data": [
                "type": "appScreenshotSets",
                "attributes": [
                    "screenshotDisplayType": displayType
                ],
                "relationships": [
                    "appStoreVersionLocalization": [
                        "data": [
                            "type": "appStoreVersionLocalizations",
                            "id": localizationID
                        ]
                    ]
                ]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: AppStoreConnectSingleResponse<ScreenshotSet> = try await request(
            path: "/v1/appScreenshotSets",
            method: "POST",
            body: body
        )
        return response.data
    }

    func listCiProducts() async throws -> [CiProduct] {
        let query = [
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "fields[ciProducts]", value: "name,createdDate,productType,bundleId,app,primaryApp,workflows"),
            URLQueryItem(name: "include", value: "app,primaryApp")
        ]
        let response: AppStoreConnectListResponse<CiProduct> = try await request(
            path: "/v1/ciProducts",
            queryItems: query
        )
        return response.data.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func listCiWorkflows(productID: String) async throws -> [CiWorkflow] {
        let query = [
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(
                name: "fields[ciWorkflows]",
                value: "name,description,isEnabled,clean,containerFilePath,platformType,createdDate"
            )
        ]
        let response: AppStoreConnectListResponse<CiWorkflow> = try await request(
            path: "/v1/ciProducts/\(productID)/workflows",
            queryItems: query
        )
        return response.data.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func readCiWorkflow(id: String) async throws -> CiWorkflow {
        let query = [
            URLQueryItem(
                name: "fields[ciWorkflows]",
                value: "name,description,isEnabled,clean,containerFilePath,platformType,createdDate"
            )
        ]
        let response: AppStoreConnectSingleResponse<CiWorkflow> = try await request(
            path: "/v1/ciWorkflows/\(id)",
            queryItems: query
        )
        return response.data
    }

    func listCiBuildRuns(workflowID: String, limit: Int = 20) async throws -> [CiBuildRun] {
        let query = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(
                name: "fields[ciBuildRuns]",
                value: "number,createdDate,startedDate,finishedDate,isPullRequestBuild,executionProgress,completionStatus,workflow"
            )
        ]
        let response: AppStoreConnectListResponse<CiBuildRun> = try await request(
            path: "/v1/ciWorkflows/\(workflowID)/buildRuns",
            queryItems: query
        )
        return response.data.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
    }

    func startCiBuildRun(workflowID: String, branch: String) async throws -> CiBuildRun {
        let body = try Self.makeCiBuildRunCreateBody(workflowID: workflowID, branch: branch)
        let response: AppStoreConnectSingleResponse<CiBuildRun> = try await request(
            path: "/v1/ciBuildRuns",
            method: "POST",
            body: body
        )
        return response.data
    }

    func updateCiWorkflowEnabled(id: String, isEnabled: Bool) async throws -> CiWorkflow {
        let body = try Self.makeCiWorkflowEnabledUpdateBody(id: id, isEnabled: isEnabled)
        let response: AppStoreConnectSingleResponse<CiWorkflow> = try await request(
            path: "/v1/ciWorkflows/\(id)",
            method: "PATCH",
            body: body
        )
        return response.data
    }

    static func makeCiBuildRunCreateBody(workflowID: String, branch: String) throws -> Data {
        var attributes: [String: Any] = [:]
        let sourceBranchOrTag = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceBranchOrTag.isEmpty {
            attributes["sourceBranchOrTag"] = sourceBranchOrTag
        }

        var data: [String: Any] = [
            "type": "ciBuildRuns",
            "relationships": [
                "workflow": [
                    "data": [
                        "type": "ciWorkflows",
                        "id": workflowID
                    ]
                ]
            ]
        ]
        if !attributes.isEmpty {
            data["attributes"] = attributes
        }

        return try JSONSerialization.data(withJSONObject: ["data": data])
    }

    static func makeCiWorkflowEnabledUpdateBody(id: String, isEnabled: Bool) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "id": id,
                "type": "ciWorkflows",
                "attributes": [
                    "isEnabled": isEnabled
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private func request<T: Decodable>(
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

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try makeJWT())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStoreConnectClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw AppStoreConnectClientError.requestFailed(apiErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
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
