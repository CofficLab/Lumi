import Foundation

// MARK: - MiniMaxImageConstants

/// MiniMax 图片生成 API 常量集合。
///
/// 集中管理端点 URL、模型枚举、宽高比等硬编码值，避免散落在业务代码中。
public enum MiniMaxImageConstants {
    // MARK: - Endpoints

    /// MiniMax 图片生成服务的基础 URL。
    public static let baseURL: String = "https://api.minimaxi.com"

    /// 图片生成端点（POST /v1/image_generation）。
    public static let imageGenerationPath: String = "/v1/image_generation"

    // MARK: - Content Types

    public static let jsonContentType: String = "application/json"
    public static let imageMimeType: String = "image/png"
}

// MARK: - MiniMaxImageModel

/// MiniMax 图片生成支持的模型枚举。
///
/// - `image-01`: 基础文生图模型，支持自定义 width/height。
/// - `image-01-live`: 支持画风设置的模型（漫画/元气/中世纪/水彩）。
public enum MiniMaxImageModel: String, CaseIterable, Sendable {
    /// 基础文生图模型，支持自定义尺寸和 21:9 宽高比。
    case image01 = "image-01"

    /// 支持画风设置的模型（漫画/元气/中世纪/水彩）。
    case image01Live = "image-01-live"

    /// 默认模型。
    public static var defaultModel: MiniMaxImageModel { .image01 }
}

// MARK: - MiniMaxImageAspectRatio

/// MiniMax 图片生成支持的宽高比。
public enum MiniMaxImageAspectRatio: String, CaseIterable, Sendable {
    case square = "1:1"
    case wide16_9 = "16:9"
    case wide4_3 = "4:3"
    case wide3_2 = "3:2"
    case tall2_3 = "2:3"
    case tall3_4 = "3:4"
    case tall9_16 = "9:16"
    /// 仅 image-01 模型支持。
    case ultraWide21_9 = "21:9"

    public static var defaultAspectRatio: MiniMaxImageAspectRatio { .square }

    /// 返回对应的像素尺寸描述（用于 UI 展示）。
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

/// MiniMax 图片生成的画风类型（仅 `image-01-live` 模型生效）。
public enum MiniMaxImageStyleType: String, CaseIterable, Sendable {
    case manga = "漫画"
    case energetic = "元气"
    case medieval = "中世纪"
    case watercolor = "水彩"
}

// MARK: - MiniMaxImageRecordStatus

/// 图片生成记录的本地状态枚举。
enum MiniMaxImageRecordStatus: String, Sendable {
    /// 任务已提交，等待 API 响应。
    case pending
    /// 生成成功，已获取图片 URL。
    case success
    /// 生成失败。
    case failed
    /// 用户取消。
    case cancelled
}
