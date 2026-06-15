import Foundation

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

struct AppStoreConnectToManyRelationship: Decodable {
    let data: [AppStoreConnectResourceIdentifier]

    enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? container.decode([AppStoreConnectResourceIdentifier].self, forKey: .data) {
            data = items
        } else if let item = try? container.decode(AppStoreConnectResourceIdentifier.self, forKey: .data) {
            data = [item]
        } else {
            data = []
        }
    }
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
