import Foundation

struct AppStoreVersion: Identifiable, Equatable, Decodable {
    let id: String
    let platform: String
    let versionString: String
    let appStoreState: String
    let appVersionState: String
    let createdDate: Date?

    /// Human-readable platform label
    var platformLabel: String {
        switch platform.normalizedASCPlatform {
        case "MAC_OS": return "macOS"
        case "IOS": return "iOS"
        case "TV_OS": return "tvOS"
        case "VISION_OS": return "visionOS"
        default: return platform
        }
    }

    var isPendingDeveloperRelease: Bool {
        appStoreState.uppercased() == "PENDING_DEVELOPER_RELEASE"
    }

    var isReadOnlyVersion: Bool {
        let state = appStoreState.uppercased()
        return state == "READY_FOR_SALE" || state == "PENDING_DEVELOPER_RELEASE"
    }

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
