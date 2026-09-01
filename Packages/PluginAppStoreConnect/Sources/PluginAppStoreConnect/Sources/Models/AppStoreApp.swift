import Foundation

struct AppStoreApp: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let bundleID: String
    let sku: String
    let primaryLocale: String
    let platform: String
    let appStoreIconID: String?
    let iconURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }

    enum AttributeKeys: String, CodingKey {
        case name
        case bundleID = "bundleId"
        case sku
        case primaryLocale
        case platform
    }

    enum RelationshipKeys: String, CodingKey {
        case appStoreIcon
    }

    init(
        id: String,
        name: String,
        bundleID: String,
        sku: String,
        primaryLocale: String,
        platform: String,
        appStoreIconID: String? = nil,
        iconURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.sku = sku
        self.primaryLocale = primaryLocale
        self.platform = platform
        self.appStoreIconID = appStoreIconID
        self.iconURL = iconURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        name = try attributes.decodeIfPresent(String.self, forKey: .name) ?? AppStoreConnectLocalization.string("Untitled")
        bundleID = try attributes.decodeIfPresent(String.self, forKey: .bundleID) ?? "-"
        sku = try attributes.decodeIfPresent(String.self, forKey: .sku) ?? "-"
        primaryLocale = try attributes.decodeIfPresent(String.self, forKey: .primaryLocale) ?? "-"
        platform = try attributes.decodeIfPresent(String.self, forKey: .platform) ?? "IOS"
        if let relationships = try? container.nestedContainer(keyedBy: RelationshipKeys.self, forKey: .relationships),
           let appStoreIcon = try? relationships.decode(AppStoreConnectRelationship.self, forKey: .appStoreIcon) {
            appStoreIconID = appStoreIcon.data?.id
        } else {
            appStoreIconID = nil
        }
        iconURL = nil
    }

    func withIconURL(_ iconURL: URL?) -> AppStoreApp {
        AppStoreApp(
            id: id,
            name: name,
            bundleID: bundleID,
            sku: sku,
            primaryLocale: primaryLocale,
            platform: platform,
            appStoreIconID: appStoreIconID,
            iconURL: iconURL
        )
    }
}
