import Foundation

struct AppStoreConnectCredentials: Equatable {
    var issuerID: String
    var keyID: String
    var privateKey: String

    var isComplete: Bool {
        !issuerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !keyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

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

struct AppStoreVersion: Identifiable, Equatable, Decodable {
    let id: String
    let platform: String
    let versionString: String
    let appStoreState: String
    let appVersionState: String
    let createdDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case platform
        case versionString
        case appStoreState
        case appVersionState
        case createdDate
    }

    init(
        id: String,
        platform: String,
        versionString: String,
        appStoreState: String,
        appVersionState: String,
        createdDate: Date?
    ) {
        self.id = id
        self.platform = platform
        self.versionString = versionString
        self.appStoreState = appStoreState
        self.appVersionState = appVersionState
        self.createdDate = createdDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        platform = try attributes.decodeIfPresent(String.self, forKey: .platform) ?? "IOS"
        versionString = try attributes.decodeIfPresent(String.self, forKey: .versionString) ?? "-"
        appStoreState = try attributes.decodeIfPresent(String.self, forKey: .appStoreState) ?? "-"
        appVersionState = try attributes.decodeIfPresent(String.self, forKey: .appVersionState) ?? "-"
        createdDate = try attributes.decodeIfPresent(Date.self, forKey: .createdDate)
    }
}

struct AppStoreVersionLocalization: Identifiable, Equatable, Decodable {
    let id: String
    var locale: String
    var promotionalText: String
    var description: String
    var keywords: String
    var whatsNew: String
    var supportURL: String
    var marketingURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case locale
        case promotionalText
        case description
        case keywords
        case whatsNew
        case supportURL = "supportUrl"
        case marketingURL = "marketingUrl"
    }

    init(
        id: String,
        locale: String,
        promotionalText: String = "",
        description: String = "",
        keywords: String = "",
        whatsNew: String = "",
        supportURL: String = "",
        marketingURL: String = ""
    ) {
        self.id = id
        self.locale = locale
        self.promotionalText = promotionalText
        self.description = description
        self.keywords = keywords
        self.whatsNew = whatsNew
        self.supportURL = supportURL
        self.marketingURL = marketingURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        locale = try attributes.decodeIfPresent(String.self, forKey: .locale) ?? "en-US"
        promotionalText = try attributes.decodeIfPresent(String.self, forKey: .promotionalText) ?? ""
        description = try attributes.decodeIfPresent(String.self, forKey: .description) ?? ""
        keywords = try attributes.decodeIfPresent(String.self, forKey: .keywords) ?? ""
        whatsNew = try attributes.decodeIfPresent(String.self, forKey: .whatsNew) ?? ""
        supportURL = try attributes.decodeIfPresent(String.self, forKey: .supportURL) ?? ""
        marketingURL = try attributes.decodeIfPresent(String.self, forKey: .marketingURL) ?? ""
    }
}

struct ScreenshotSet: Identifiable, Equatable, Decodable {
    let id: String
    let screenshotDisplayType: String

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case screenshotDisplayType
    }

    init(id: String, screenshotDisplayType: String) {
        self.id = id
        self.screenshotDisplayType = screenshotDisplayType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        screenshotDisplayType = try attributes.decodeIfPresent(String.self, forKey: .screenshotDisplayType) ?? "UNKNOWN"
    }
}

struct PendingScreenshot: Identifiable, Equatable {
    enum Status: Equatable {
        case ready
        case invalid(String)
        case uploading
        case uploaded
        case failed(String)
    }

    let id = UUID()
    let url: URL
    let width: Int
    let height: Int
    var displayType: String
    var status: Status

    var fileName: String {
        url.lastPathComponent
    }
}

struct AppStoreConnectListResponse<T: Decodable>: Decodable {
    let data: [T]
}

struct AppStoreConnectListResponseWithIncluded<T: Decodable, Included: Decodable>: Decodable {
    let data: [T]
    let included: [Included]?
}

struct AppStoreConnectSingleResponse<T: Decodable>: Decodable {
    let data: T
}

struct AppStoreConnectRelationship: Decodable {
    let data: AppStoreConnectResourceIdentifier?
}

struct AppStoreConnectResourceIdentifier: Decodable {
    let type: String
    let id: String
}

struct BuildIconResource: Decodable {
    let id: String
    let iconAsset: AppStoreImageAsset?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case iconAsset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        iconAsset = try attributes.decodeIfPresent(AppStoreImageAsset.self, forKey: .iconAsset)
    }
}

struct AppStoreImageAsset: Decodable {
    let templateURL: String
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case templateURL = "templateUrl"
        case width
        case height
    }

    init(templateURL: String, width: Int? = nil, height: Int? = nil) {
        self.templateURL = templateURL
        self.width = width
        self.height = height
    }

    func url(width requestedWidth: Int, height requestedHeight: Int) -> URL? {
        let value = templateURL
            .replacingOccurrences(of: "{w}", with: "\(requestedWidth)")
            .replacingOccurrences(of: "{h}", with: "\(requestedHeight)")
            .replacingOccurrences(of: "{f}", with: "png")
        return URL(string: value)
    }
}

struct AppStoreConnectErrorResponse: Decodable {
    struct APIError: Decodable {
        let status: String?
        let code: String?
        let title: String?
        let detail: String?
    }

    let errors: [APIError]
}
