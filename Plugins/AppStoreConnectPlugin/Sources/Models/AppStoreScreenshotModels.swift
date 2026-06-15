import Foundation

struct ScreenshotSet: Identifiable, Equatable, Decodable {
    let id: String
    let screenshotDisplayType: String
    let screenshotIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }

    enum AttributeKeys: String, CodingKey {
        case screenshotDisplayType
    }

    enum RelationshipKeys: String, CodingKey {
        case appScreenshots
    }

    init(id: String, screenshotDisplayType: String, screenshotIDs: [String] = []) {
        self.id = id
        self.screenshotDisplayType = screenshotDisplayType
        self.screenshotIDs = screenshotIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        screenshotDisplayType = try attributes.decodeIfPresent(String.self, forKey: .screenshotDisplayType) ?? "UNKNOWN"
        if let relationships = try? container.nestedContainer(keyedBy: RelationshipKeys.self, forKey: .relationships),
           let screenshots = try? relationships.decode(AppStoreConnectToManyRelationship.self, forKey: .appScreenshots) {
            screenshotIDs = screenshots.data.map(\.id)
        } else {
            screenshotIDs = []
        }
    }
}

struct ScreenshotSetsPayload {
    let sets: [ScreenshotSet]
    let screenshotsBySetID: [String: [AppScreenshot]]
}

struct AppScreenshot: Identifiable, Decodable {
    let id: String
    let fileName: String
    let fileSize: Int?
    let imageAsset: AppStoreImageAsset?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case fileName
        case fileSize
        case imageAsset
    }

    init(id: String, fileName: String, fileSize: Int? = nil, imageAsset: AppStoreImageAsset? = nil) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.imageAsset = imageAsset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        fileName = try attributes.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        fileSize = try attributes.decodeIfPresent(Int.self, forKey: .fileSize)
        imageAsset = try attributes.decodeIfPresent(AppStoreImageAsset.self, forKey: .imageAsset)
    }

    var previewURL: URL? {
        let width = imageAsset?.width ?? 120
        let height = imageAsset?.height ?? 120
        return imageAsset?.url(width: width, height: height)
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
