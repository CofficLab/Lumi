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
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        order: Int,
        htmlFileName: String = "index.html",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.htmlFileName = htmlFileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AppStorePromoTask: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

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

    public var htmlURL: URL { directoryURL.appendingPathComponent(image.htmlFileName) }
    public var assetsDirectoryURL: URL { directoryURL.appendingPathComponent("assets", isDirectory: true) }

    public init(task: AppStorePromoTask, image: AppStorePromoImage, directoryURL: URL, html: String) {
        self.task = task
        self.image = image
        self.directoryURL = directoryURL
        self.html = html
    }
}
