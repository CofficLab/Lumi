import Foundation

/// App Store Connect REST JSON cache under the plugin database folder.
///
/// Layout: `AppStoreConnectPlugin/api-cache/{manifest.json, indexes/, objects/}`
enum ConnectAPICacheConfiguration {
    static let pluginName = "AppStoreConnectPlugin"
    static let cacheDirectoryName = "api-cache"
    static let objectsDirectoryName = "objects"
    static let indexesDirectoryName = "indexes"
    static let manifestFileName = "manifest.json"
    static let versionStatesFileName = "version-states.json"

    static let memoryTTL: TimeInterval = 5 * 60
    static let memoryMaxEntries = 64

    static let diskByteLimit: Int64 = 50 * 1024 * 1024
    static let diskTargetByteCount: Int64 = 40 * 1024 * 1024
    static let staleAccessInterval: TimeInterval = 90 * 24 * 60 * 60

    static let volatileTTL: TimeInterval = 2 * 60
    static let standardTTL: TimeInterval = 60 * 60
    static let stableTTL: TimeInterval = 24 * 60 * 60
}

enum ConnectCacheRetention: String, Codable, Sendable {
    case volatile
    case standard
    case stable
    case immutable

    var ttl: TimeInterval? {
        switch self {
        case .volatile:
            return ConnectAPICacheConfiguration.volatileTTL
        case .standard:
            return ConnectAPICacheConfiguration.standardTTL
        case .stable:
            return ConnectAPICacheConfiguration.stableTTL
        case .immutable:
            return nil
        }
    }

    func isExpired(fetchedAt: Date, now: Date) -> Bool {
        guard let ttl else { return false }
        return now.timeIntervalSince(fetchedAt) > ttl
    }
}

enum ConnectCacheTag: Codable, Equatable, Hashable, Sendable {
    case app(String)
    case version(String)
    case localization(String)
    case screenshotSet(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let id = try container.decode(String.self, forKey: .id)
        switch type {
        case "app": self = .app(id)
        case "version": self = .version(id)
        case "localization": self = .localization(id)
        case "screenshotSet": self = .screenshotSet(id)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown tag type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let id):
            try container.encode("app", forKey: .type)
            try container.encode(id, forKey: .id)
        case .version(let id):
            try container.encode("version", forKey: .type)
            try container.encode(id, forKey: .id)
        case .localization(let id):
            try container.encode("localization", forKey: .type)
            try container.encode(id, forKey: .id)
        case .screenshotSet(let id):
            try container.encode("screenshotSet", forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

struct ConnectAPICacheEntry: Codable, Equatable {
    let key: String
    let objectName: String
    let method: String
    let path: String
    let retention: ConnectCacheRetention
    let byteCount: Int
    var fetchedAt: Date
    var lastAccess: Date
    let tags: [ConnectCacheTag]
}

struct ConnectAPICacheManifest: Codable {
    var entries: [ConnectAPICacheEntry]
}

struct ConnectAPICacheDiskUsage: Equatable {
    let fileCount: Int
    let byteCount: Int64
}

struct ConnectCachePolicy: Sendable {
    let retention: ConnectCacheRetention
    let tags: [ConnectCacheTag]
}
