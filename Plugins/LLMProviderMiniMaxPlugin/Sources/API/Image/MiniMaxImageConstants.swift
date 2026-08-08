import Foundation

// MARK: - MiniMaxImageConstants

/// MiniMax 图片生成 API 常量集合。
public enum MiniMaxImageConstants {
    // MARK: - Endpoints

    public static let baseURL: String = "https://api.minimaxi.com"
    public static let imageGenerationPath: String = "/v1/image_generation"

    // MARK: - Content Types

    public static let jsonContentType: String = "application/json"
    public static let imageMimeType: String = "image/png"
}

// MARK: - MiniMaxImageModel

public enum MiniMaxImageModel: String, CaseIterable, Sendable {
    case image01 = "image-01"
    case image01Live = "image-01-live"

    public static var defaultModel: MiniMaxImageModel { .image01 }
}

// MARK: - MiniMaxImageAspectRatio

public enum MiniMaxImageAspectRatio: String, CaseIterable, Sendable {
    case square = "1:1"
    case wide16_9 = "16:9"
    case wide4_3 = "4:3"
    case wide3_2 = "3:2"
    case tall2_3 = "2:3"
    case tall3_4 = "3:4"
    case tall9_16 = "9:16"
    case ultraWide21_9 = "21:9"

    public static var defaultAspectRatio: MiniMaxImageAspectRatio { .square }

    public var pixelSize: String {
        switch self {
        case .square: return "1024×1024"
        case .wide16_9: return "1280×720"
        case .wide4_3: return "1152×864"
        case .wide3_2: return "1248×832"
        case .tall2_3: return "832×1248"
        case .tall3_4: return "864×1152"
        case .tall9_16: return "720×1280"
        case .ultraWide21_9: return "1344×576"
        }
    }
}

// MARK: - MiniMaxImageStyleType

public enum MiniMaxImageStyleType: String, CaseIterable, Sendable {
    case manga = "漫画"
    case energetic = "元气"
    case medieval = "中世纪"
    case watercolor = "水彩"
}
