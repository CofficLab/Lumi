import Foundation

/// App Store Connect Age Rating Declaration: read & update.
///
/// Model notes (verified against the official API, 2026-10):
/// - The age-rating declaration is an **app-level** resource attached to an `AppInfo`,
///   not to an `AppStoreVersion`. New versions share the same declaration.
/// - The version-level endpoints
///   (`GET /v1/appStoreVersions/{id}/ageRatingDeclaration` and its relationships)
///   were deprecated since API 1.4 and **removed in API 4.3** — they can no longer be used.
/// - There is no public `create` endpoint: the declaration is created the first time the
///   questionnaire is completed on the App Store Connect website (App Information → Age Ratings).
///   After that, read + PATCH fully work and new versions inherit the same declaration.
extension ConnectClient {
    /// Read the age-rating declaration for a version.
    ///
    /// Canonical path: version → app → preferred appInfo → declaration.
    /// Returns nil when the app has no declaration yet (brand-new app that never completed
    /// the questionnaire on the website).
    func readAgeRatingDeclaration(versionID: String) async throws -> AgeRatingDeclaration? {
        Self.logger.info("\(Self.t)readAgeRatingDeclaration versionID=\(versionID)")
        guard let appID = try await resolveAppID(versionID: versionID) else {
            Self.logger.info("\(Self.t)readAgeRatingDeclaration could not resolve app for version")
            return nil
        }
        return try await readAgeRatingDeclarationByApp(appID: appID)
    }

    /// Resolve the owning app id from a version resource (`include=app`, to-one relationship).
    ///
    /// NOTE (2026-10-10 实测): 该端点若同时带 `fields[appStoreVersions]=...`，
    /// Apple 会把 `data.relationships` 整个清空（`include=app` 失效），导致
    /// app 关系丢失、本方法解出 nil —— 年龄分级/提交状态检查会因此静默误报。
    /// 所以这里只用 `fields[apps]=name` 瘦身 included 的 app，并且用 included
    /// 数组兜底，任何情况下都能拿到 app id。
    func resolveAppID(versionID: String) async throws -> String? {
        Self.logger.info("\(Self.t)resolveAppID versionID=\(versionID)")
        do {
            let response: VersionWithAppResponse = try await request(
                path: "/v1/appStoreVersions/\(versionID)",
                queryItems: [
                    URLQueryItem(name: "include", value: "app"),
                    URLQueryItem(name: "fields[apps]", value: "name"),
                ]
            )
            return response.resolvedAppID
        } catch let error as AppStoreConnectClientError {
            if case .resourceNotFound = error { return nil }
            throw error
        }
    }

    /// Read the age-rating declaration of an app via its appInfo(s).
    ///
    /// App infos are walked in preference order (editable → live → any) and the first
    /// appInfo that has a declaration wins, so read/update work regardless of the
    /// app's current state.
    func readAgeRatingDeclarationByApp(appID: String) async throws -> AgeRatingDeclaration? {
        Self.logger.info("\(Self.t)readAgeRatingDeclarationByApp appID=\(appID)")
        let appInfoIDs = try await resolvePreferredAppInfoIDs(appID: appID)
        guard !appInfoIDs.isEmpty else {
            Self.logger.info("\(Self.t)readAgeRatingDeclarationByApp no appInfo resolved")
            return nil
        }
        for appInfoID in appInfoIDs {
            if let declaration = try await readAgeRatingDeclaration(appInfoID: appInfoID) {
                Self.logger.info("\(Self.t)readAgeRatingDeclarationByApp found declaration on appInfo=\(appInfoID)")
                return declaration
            }
        }
        return nil
    }

    /// Directly read the age-rating declaration of an appInfo.
    func readAgeRatingDeclaration(appInfoID: String) async throws -> AgeRatingDeclaration? {
        Self.logger.info("\(Self.t)readAgeRatingDeclaration appInfoID=\(appInfoID)")
        do {
            let response: AppStoreConnectSingleResponse<AgeRatingDeclaration> = try await request(
                path: "/v1/appInfos/\(appInfoID)/ageRatingDeclaration"
            )
            return response.data
        } catch let error as AppStoreConnectClientError {
            if case .resourceNotFound = error { return nil }
            throw error
        }
    }

    /// AppInfo states whose declaration is currently editable (mirrors the App Store
    /// Connect website / fastlane `fetch_edit_app_info`).
    private static let editableAppInfoStates: Set<String> = [
        "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "WAITING_FOR_REVIEW",
    ]

    /// AppInfo states that represent a live (or about-to-be-live) app.
    private static let liveAppInfoStates: Set<String> = [
        "READY_FOR_DISTRIBUTION", "PENDING_RELEASE", "IN_REVIEW",
        "READY_FOR_SALE", "ACCEPTED", "READY_FOR_REVIEW",
    ]

    /// List an app's appInfos and order them by preference: editable → live → any.
    func resolvePreferredAppInfoIDs(appID: String) async throws -> [String] {
        Self.logger.info("\(Self.t)resolvePreferredAppInfoIDs appID=\(appID)")
        let query = [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "fields[appInfos]", value: "appStoreState,state"),
        ]
        let response: AppStoreConnectListResponse<AppInfoSummary> = try await request(
            path: "/v1/apps/\(appID)/appInfos",
            queryItems: query
        )
        let infos = response.data
        let editable = infos.filter { Self.editableAppInfoStates.contains($0.effectiveState) }
        let live = infos.filter { Self.liveAppInfoStates.contains($0.effectiveState) }
        let rest = infos.filter { info in
            !Self.editableAppInfoStates.contains(info.effectiveState)
                && !Self.liveAppInfoStates.contains(info.effectiveState)
        }
        let ordered = editable + live + rest
        if Self.verbose {
            for info in ordered {
                Self.logger.info("\(Self.t)  - appInfo=\(info.id) state=\(info.state ?? "nil") appStoreState=\(info.appStoreState ?? "nil")")
            }
        }
        return ordered.map(\.id)
    }

    /// Patch an existing age-rating declaration. Only non-nil fields are sent.
    func updateAgeRating(
        declarationID: String,
        attributes: [String: Any]
    ) async throws -> AgeRatingDeclaration {
        let payload: [String: Any] = [
            "data": [
                "type": "ageRatingDeclarations",
                "id": declarationID,
                "attributes": attributes
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        Self.logger.info("\(Self.t)updateAgeRating id=\(declarationID)")
        let response: AppStoreConnectSingleResponse<AgeRatingDeclaration> = try await request(
            path: "/v1/ageRatingDeclarations/\(declarationID)",
            method: "PATCH",
            body: body
        )
        return response.data
    }
}

/// Lightweight decodable for `GET /v1/apps/{id}/appInfos` list items.
private struct AppInfoSummary: Decodable {
    let id: String
    let state: String?
    let appStoreState: String?

    /// `state` is the current enum; `appStoreState` is the legacy one (deprecated since
    /// API 3.3). Prefer `state`, fall back to `appStoreState`.
    var effectiveState: String {
        state ?? appStoreState ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, attributes
    }

    enum AttributeKeys: String, CodingKey {
        case state
        case appStoreState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let attrs = try? container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes) {
            state = try? attrs.decode(String.self, forKey: .state)
            appStoreState = try? attrs.decode(String.self, forKey: .appStoreState)
        } else {
            state = nil
            appStoreState = nil
        }
    }
}

/// 响应容器：优先取 `data.relationships.app.data.id`，失败时从 `included`
/// 数组中找 `type == "apps"` 的条目兜底（服务器在特定查询组合下会清空
/// relationships，但 included 里的 app 始终存在）。
private struct VersionWithAppResponse: Decodable {
    struct DataResource: Decodable {
        struct AppRelationship: Decodable {
            let data: AppStoreConnectResourceIdentifier?
        }
        struct Relationships: Decodable {
            let app: AppRelationship?
        }
        let relationships: Relationships?
    }

    let data: DataResource
    let included: [AppStoreConnectResourceIdentifier]?

    var resolvedAppID: String? {
        if let id = data.relationships?.app?.data?.id { return id }
        return included?.first(where: { $0.type == "apps" })?.id
    }
}

/// App Store Connect `ageRatingDeclarations` resource.
struct AgeRatingDeclaration: Decodable {
    let id: String
    let alcoholTobaccoOrDrugUseOrReferences: String?
    let contests: String?
    let gambling: Bool?
    let gamblingSimulated: String?
    let horrorOrFearThemes: String?
    let kidsAgeBand: String?
    let medicalOrTreatmentInformation: String?
    let profanityOrCrudeHumor: String?
    let seventeenPlus: Bool?
    let sexualContentGraphicAndNudity: String?
    let sexualContentOrNudity: String?
    let unrestrictedWebAccess: Bool?
    let violenceCartoonOrFantasy: String?
    let violenceRealistic: String?
    let violenceRealisticProlongedGraphicOrSadistic: String?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case alcoholTobaccoOrDrugUseOrReferences
        case contests
        case gambling
        case gamblingSimulated
        case horrorOrFearThemes
        case kidsAgeBand
        case medicalOrTreatmentInformation
        case profanityOrCrudeHumor
        case seventeenPlus
        case sexualContentGraphicAndNudity
        case sexualContentOrNudity
        case unrestrictedWebAccess
        case violenceCartoonOrFantasy
        case violenceRealistic
        case violenceRealisticProlongedGraphicOrSadistic
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attrs = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        alcoholTobaccoOrDrugUseOrReferences = try attrs.decodeIfPresent(String.self, forKey: .alcoholTobaccoOrDrugUseOrReferences)
        contests = try attrs.decodeIfPresent(String.self, forKey: .contests)
        gambling = try attrs.decodeIfPresent(Bool.self, forKey: .gambling)
        gamblingSimulated = try attrs.decodeIfPresent(String.self, forKey: .gamblingSimulated)
        horrorOrFearThemes = try attrs.decodeIfPresent(String.self, forKey: .horrorOrFearThemes)
        kidsAgeBand = try attrs.decodeIfPresent(String.self, forKey: .kidsAgeBand)
        medicalOrTreatmentInformation = try attrs.decodeIfPresent(String.self, forKey: .medicalOrTreatmentInformation)
        profanityOrCrudeHumor = try attrs.decodeIfPresent(String.self, forKey: .profanityOrCrudeHumor)
        seventeenPlus = try attrs.decodeIfPresent(Bool.self, forKey: .seventeenPlus)
        sexualContentGraphicAndNudity = try attrs.decodeIfPresent(String.self, forKey: .sexualContentGraphicAndNudity)
        sexualContentOrNudity = try attrs.decodeIfPresent(String.self, forKey: .sexualContentOrNudity)
        unrestrictedWebAccess = try attrs.decodeIfPresent(Bool.self, forKey: .unrestrictedWebAccess)
        violenceCartoonOrFantasy = try attrs.decodeIfPresent(String.self, forKey: .violenceCartoonOrFantasy)
        violenceRealistic = try attrs.decodeIfPresent(String.self, forKey: .violenceRealistic)
        violenceRealisticProlongedGraphicOrSadistic = try attrs.decodeIfPresent(String.self, forKey: .violenceRealisticProlongedGraphicOrSadistic)
    }
}
