import Foundation

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
