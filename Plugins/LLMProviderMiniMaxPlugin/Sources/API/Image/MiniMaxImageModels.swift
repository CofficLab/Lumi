import Foundation

// MARK: - MiniMax Image API DTOs

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
        case model, prompt, style, aspectRatio, width, height
        case responseFormat = "response_format"
        case seed, n
        case subjectReference = "subject_reference"
        case promptOptimizer = "prompt_optimizer"
        case aigcWatermark = "aigc_watermark"
    }
}

struct MiniMaxImageStyleObject: Encodable, Equatable, Sendable {
    let styleType: String
    let styleWeight: Float?

    enum CodingKeys: String, CodingKey {
        case styleType = "style_type"
        case styleWeight = "style_weight"
    }
}

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

struct MiniMaxImageGenerationResponse: Decodable, Equatable, Sendable {
    let id: String?
    let data: MiniMaxImageData?
    let metadata: MiniMaxImageMetadata?
    let baseResp: MiniMaxBaseResp

    enum CodingKeys: String, CodingKey {
        case id, data, metadata
        case baseResp = "base_resp"
    }
}

struct MiniMaxImageData: Decodable, Equatable, Sendable {
    let imageUrls: [String]?
    let imageBase64: [String]?

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
        case imageBase64 = "image_base64"
    }
}

struct MiniMaxImageMetadata: Decodable, Equatable, Sendable {
    let successCount: String?
    let failedCount: String?

    enum CodingKeys: String, CodingKey {
        case successCount = "success_count"
        case failedCount = "failed_count"
    }
}
