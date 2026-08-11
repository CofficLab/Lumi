import CoreGraphics
import Foundation

public enum AppStorePromoDeviceFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case iphone
    case ipad
    case mac

    public var id: String { rawValue }

    public var displayTypes: [String] {
        AppStorePromoDisplaySpec.presets
            .filter { $0.family == self }
            .map(\.displayType)
    }
}

public struct AppStorePromoDisplayPreset: Codable, Equatable, Identifiable, Sendable {
    public let displayType: String
    public let family: AppStorePromoDeviceFamily
    public let width: Int
    public let height: Int

    public var id: String { displayType }
    public var cgSize: CGSize { CGSize(width: width, height: height) }
    public var isPortrait: Bool { height >= width }

    public init(displayType: String, family: AppStorePromoDeviceFamily, width: Int, height: Int) {
        self.displayType = displayType
        self.family = family
        self.width = width
        self.height = height
    }
}

public enum AppStorePromoDisplaySpec {
    public static let presets: [AppStorePromoDisplayPreset] = [
        .init(displayType: "APP_IPHONE_67", family: .iphone, width: 1290, height: 2796),
        .init(displayType: "APP_IPHONE_65", family: .iphone, width: 1284, height: 2778),
        .init(displayType: "APP_IPHONE_61", family: .iphone, width: 1170, height: 2532),
        .init(displayType: "APP_IPHONE_58", family: .iphone, width: 1170, height: 2532),
        .init(displayType: "APP_IPAD_PRO_3GEN_129", family: .ipad, width: 2048, height: 2732),
        .init(displayType: "APP_IPAD_PRO_3GEN_11", family: .ipad, width: 1668, height: 2388),
        .init(displayType: "APP_DESKTOP", family: .mac, width: 1280, height: 800),
    ]

    public static func preset(for displayType: String) -> AppStorePromoDisplayPreset? {
        presets.first { $0.displayType == displayType }
    }

    public static func presets(for family: AppStorePromoDeviceFamily) -> [AppStorePromoDisplayPreset] {
        presets.filter { $0.family == family }
    }
}

public struct AppStorePromoImage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var order: Int
    public var htmlFileName: String
    public var localeIdentifiers: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        order: Int,
        htmlFileName: String = "index.html",
        localeIdentifiers: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.htmlFileName = htmlFileName
        self.localeIdentifiers = localeIdentifiers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, order, htmlFileName, localeIdentifiers, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        order = try container.decode(Int.self, forKey: .order)
        htmlFileName = try container.decodeIfPresent(String.self, forKey: .htmlFileName) ?? "index.html"
        localeIdentifiers = try container.decodeIfPresent([String].self, forKey: .localeIdentifiers) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public struct AppStorePromoTask: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var id: String
    public var title: String
    public var appName: String
    public var deviceFamily: AppStorePromoDeviceFamily
    public var localeIdentifier: String
    public var images: [AppStorePromoImage]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = AppStorePromoTask.currentSchemaVersion,
        id: String,
        title: String,
        appName: String,
        deviceFamily: AppStorePromoDeviceFamily,
        localeIdentifier: String = "en-US",
        images: [AppStorePromoImage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.appName = appName
        self.deviceFamily = deviceFamily
        self.localeIdentifier = localeIdentifier
        self.images = images
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AppStorePromoResolvedImage: Equatable, Sendable {
    public let task: AppStorePromoTask
    public let image: AppStorePromoImage
    public let directoryURL: URL
    public let html: String
    public let localeIdentifier: String
    private let resolvedHTMLURL: URL

    public var htmlURL: URL { resolvedHTMLURL }
    public var assetsDirectoryURL: URL { directoryURL.appendingPathComponent("assets", isDirectory: true) }

    public init(
        task: AppStorePromoTask,
        image: AppStorePromoImage,
        directoryURL: URL,
        html: String,
        localeIdentifier: String? = nil,
        htmlURL: URL? = nil
    ) {
        self.task = task
        self.image = image
        self.directoryURL = directoryURL
        self.html = html
        self.localeIdentifier = localeIdentifier ?? task.localeIdentifier
        self.resolvedHTMLURL = htmlURL ?? directoryURL.appendingPathComponent(image.htmlFileName)
    }
}

public struct AppStorePromoLocale: Equatable, Hashable, Identifiable, Sendable {
    public static let common: [AppStorePromoLocale] = [
        "en-US", "en-GB", "zh-Hans", "zh-Hant", "ja", "ko", "fr-FR", "de-DE",
        "es-ES", "pt-BR", "it", "nl-NL", "ru", "ar", "tr", "th", "vi"
    ].map(AppStorePromoLocale.init(identifier:))

    public let identifier: String
    public var id: String { identifier }

    public init(identifier: String) {
        self.identifier = identifier
    }

    public var localizedName: String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    public var displayName: String { "\(localizedName) · \(identifier)" }

    public static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Za-z]{2,3}(?:-[A-Za-z]{2,4}|-[0-9]{3})*$"#
        guard !trimmed.isEmpty, trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return trimmed.split(separator: "-").enumerated().map { index, part in
            if index == 0 { return part.lowercased() }
            if part.count == 4 { return part.prefix(1).uppercased() + part.dropFirst().lowercased() }
            if part.count == 2 { return part.uppercased() }
            return String(part)
        }.joined(separator: "-")
    }
}
