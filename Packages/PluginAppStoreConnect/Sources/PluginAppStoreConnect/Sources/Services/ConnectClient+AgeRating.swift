import Foundation

/// App Store Connect Age Rating Declaration: read & update.
extension ConnectClient {
    /// Read the age-rating declaration for a version.
    /// Returns nil when no declaration exists yet (Apple returns 404 for brand-new versions).
    func readAgeRatingDeclaration(versionID: String) async throws -> AgeRatingDeclaration? {
        Self.logger.info("\(Self.t)readAgeRatingDeclaration versionID=\(versionID)")
        do {
            let response: AppStoreConnectSingleResponse<AgeRatingDeclaration> = try await request(
                path: "/v1/appStoreVersions/\(versionID)/ageRatingDeclaration"
            )
            return response.data
        } catch let error as AppStoreConnectClientError {
            if case .resourceNotFound = error {
                return nil
            }
            throw error
        }
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
