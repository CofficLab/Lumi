import Foundation

// MARK: - Step 1: Create Video Task

struct MiniMaxVideoTaskCreateRequest: Encodable, Equatable, Sendable {
    let model: String, prompt: String, duration: Int?, resolution: String?
    let promptOptimizer: Bool?, fastPretreatment: Bool?, aigcWatermark: Bool?
    enum CodingKeys: String, CodingKey {
        case model, prompt, duration, resolution
        case promptOptimizer = "prompt_optimizer"
        case fastPretreatment = "fast_pretreatment"
        case aigcWatermark = "aigc_watermark"
    }
}

struct MiniMaxVideoTaskCreateResponse: Decodable, Equatable, Sendable {
    let taskId: String?
    let baseResp: MiniMaxBaseResp
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case baseResp = "base_resp"
    }
}

// MARK: - Step 2: Query Video Task

struct MiniMaxVideoTaskQueryResponse: Decodable, Equatable, Sendable {
    let status: String?, fileId: String?, errorMessage: String?
    let baseResp: MiniMaxBaseResp
    enum CodingKeys: String, CodingKey {
        case status
        case fileId = "file_id"
        case errorMessage = "error_message"
        case baseResp = "base_resp"
    }
    var taskStatus: MiniMaxVideoTaskStatus? {
        guard let status else { return nil }
        return MiniMaxVideoTaskStatus(rawValue: status)
    }
    var isSuccess: Bool { taskStatus == .success }
    var isFailure: Bool { taskStatus == .fail }
    var isTerminal: Bool { taskStatus?.isTerminal ?? false }
}

// MARK: - Step 3: Retrieve File

struct MiniMaxFileRetrieveResponse: Decodable, Equatable, Sendable {
    let file: MiniMaxFileInfo?
    let baseResp: MiniMaxBaseResp
    struct MiniMaxFileInfo: Decodable, Equatable, Sendable {
        let fileId: Int64?, bytes: Int64?, createdAt: Int64?
        let filename: String?, purpose: String?, downloadUrl: String?
        enum CodingKeys: String, CodingKey {
            case fileId = "file_id", bytes, createdAt = "created_at", filename, purpose
            case downloadUrl = "download_url"
        }
    }
    enum CodingKeys: String, CodingKey {
        case file
        case baseResp = "base_resp"
    }
    func resolveDownloadURL() -> URL? {
        guard let raw = file?.downloadUrl, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
    func preferredFilename() -> String {
        if let name = file?.filename, !name.isEmpty { return name }
        return "minimax_video.mp4"
    }
    func byteCount() -> Int64? { file?.bytes }
}
