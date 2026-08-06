import Foundation

// MARK: - MiniMax Image API DTOs
//
// MiniMax 图片生成服务（POST /v1/image_generation）的请求/响应模型。
// 所有 DTO 仅在 `Sources/Model/` 和 `Sources/Tools/` 内部使用，不对外暴露。

// MARK: - Step 1: Generate Image

/// 图片生成请求体：`POST /v1/image_generation`。
///
/// 字段对齐 MiniMax 官方文档：
/// - `model`: 必填，`image-01` 或 `image-01-live`
/// - `prompt`: 必填，最长 1500 字符
/// - `style`: 可选，仅 `image-01-live` 生效
/// - `aspect_ratio`: 可选，默认 `1:1`
/// - `width` / `height`: 可选，仅 `image-01` 生效（512–2048，8 的倍数）
/// - `response_format`: 可选，`url`（默认）或 `base64`
/// - `seed`: 可选，随机种子
/// - `n`: 可选，1–9，默认 1
/// - `prompt_optimizer`: 可选
/// - `aigc_watermark`: 可选
struct MiniMaxImageGenerationRequest: Encodable, Equatable, Sendable {
    let model: String
    let prompt: String
    let subjectReference: [MiniMaxImageSubjectReference]?
    let style: MiniMaxImageStyleObject?
    let aspectRatio: String?
    let width: Int?
    let height: Int?
    let responseFormat: String?
    let seed: Int?
    let n: Int?
    let promptOptimizer: Bool?
    let aigcWatermark: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case subjectReference = "subject_reference"
        case style
        case aspectRatio = "aspect_ratio"
        case width
        case height
        case responseFormat = "response_format"
        case seed
        case n
        case promptOptimizer = "prompt_optimizer"
        case aigcWatermark = "aigc_watermark"
    }
}

/// 画风设置对象（仅 `image-01-live` 模型生效）。
struct MiniMaxImageStyleObject: Encodable, Equatable, Sendable {
    let styleType: String
    let styleWeight: Float?

    enum CodingKeys: String, CodingKey {
        case styleType = "style_type"
        case styleWeight = "style_weight"
    }
}

/// 人物主体参考，用于图生图（`subject_reference`）。
///
/// - `type`: 主体类型，当前仅支持 `character`（人像）。
/// - `imageFile`: 参考图文件，支持公网 URL 或 Base64 Data URL。
///   格式要求：JPG/JPEG/PNG，小于 10MB。为获得最佳效果，请上传单人正面照片。
public struct MiniMaxImageSubjectReference: Encodable, Equatable, Sendable {
    let type: String
    let imageFile: String

    enum CodingKeys: String, CodingKey {
        case type
        case imageFile = "image_file"
    }

    public init(type: String, imageFile: String) {
        self.type = type
        self.imageFile = imageFile
    }
}

// MARK: - Response

/// 图片生成响应：`POST /v1/image_generation`。
///
/// 响应结构：
/// ```json
/// {
///   "id": "任务ID",
///   "data": { "image_urls": ["...", "..."] },
///   "metadata": { "success_count": 2, "failed_count": 0 },
///   "base_resp": { "status_code": 0, "status_msg": "success" }
/// }
/// ```
struct MiniMaxImageGenerationResponse: Decodable, Equatable, Sendable {
    let id: String?
    let data: MiniMaxImageData?
    let metadata: MiniMaxImageMetadata?
    let baseResp: MiniMaxBaseResp

    enum CodingKeys: String, CodingKey {
        case id
        case data
        case metadata
        case baseResp = "base_resp"
    }
}

/// 响应中的 `data` 字段，包含图片链接或 Base64 数据。
struct MiniMaxImageData: Decodable, Equatable, Sendable {
    let imageUrls: [String]?
    let imageBase64: [String]?

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case imageBase64 = "image_base64"
    }
}

/// 响应中的 `metadata` 字段，包含生成统计信息。
///
/// - 注意：MiniMax API 返回的 `success_count` 和 `failed_count` 是**字符串**（如 `"1"`），
///   而非整数。因此这里用 `String?` 解码，在 client 层做 `Int()` 转换。
struct MiniMaxImageMetadata: Decodable, Equatable, Sendable {
    let successCount: String?
    let failedCount: String?

    enum CodingKeys: String, CodingKey {
        case successCount = "success_count"
        case failedCount = "failed_count"
    }
}

// MARK: - Errors

/// 图片生成流程中可被 UI 区分的错误类型。
enum MiniMaxImageError: LocalizedError, Equatable {
    /// 未配置 API Key。
    case missingAPIKey
    /// 业务错误：HTTP 200 但 `base_resp.status_code != 0`。
    case apiError(code: Int, message: String)
    /// 响应中无有效图片 URL。
    case noImagesReturned
    /// 工具被取消。
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "MiniMax API Key is not configured. Please add your API key in Lumi settings."
        case .apiError(let code, let message):
            return "MiniMax API error (code=\(code)): \(message)"
        case .noImagesReturned:
            return "MiniMax did not return any images. The prompt may have been blocked by content safety."
        case .cancelled:
            return "MiniMax image generation was cancelled."
        }
    }
}
