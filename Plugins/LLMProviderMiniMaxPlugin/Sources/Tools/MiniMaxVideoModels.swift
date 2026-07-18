import Foundation

// MARK: - MiniMax Video API DTOs
//
// MiniMax 视频生成服务（https://api.minimaxi.com/v1/video_generation）的
// 请求/响应模型。所有 DTO 仅在 `Sources/Tools/` 内部使用，不对外暴露。
//
// MiniMax API 响应统一包络：
//   { "task_id": "...", "base_resp": { "status_code": 0, "status_msg": "success" } }
//
// 非 0 的 `status_code` 表示业务错误（鉴权、配额、参数等）。
// HTTP 状态码由 `HTTPClient` 抛 `HTTPClientError.httpError`；本层只关心
// HTTP 200 但 `base_resp.status_code != 0` 的"业务错误"情况。

// MARK: - Base Response Envelope

/// 所有 MiniMax API 响应的通用包络字段。
struct MiniMaxBaseResp: Decodable, Equatable, Sendable {
    let statusCode: Int
    let statusMessage: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMessage = "status_msg"
    }

    var isSuccess: Bool { statusCode == 0 }

    var errorDescription: String {
        statusMessage.isEmpty ? "MiniMax API error (status_code=\(statusCode))" : statusMessage
    }
}

// MARK: - Step 1: Create Video Task

/// Step 1 请求体：`POST /v1/video_generation`。
///
/// 字段对齐 MiniMax 官方文档：
/// - `model`: 必填
/// - `prompt`: 必填
/// - `duration`: 可选，6 或 10
/// - `resolution`: 可选，720P / 768P / 1080P
/// - `prompt_optimizer`: 可选，是否自动优化 prompt
/// - `fast_pretreatment`: 可选，是否加速预处理
/// - `aigc_watermark`: 可选，是否添加 AIGC 水印
struct MiniMaxVideoTaskCreateRequest: Encodable, Equatable, Sendable {
    let model: String
    let prompt: String
    let duration: Int?
    let resolution: String?
    let promptOptimizer: Bool?
    let fastPretreatment: Bool?
    let aigcWatermark: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case duration
        case resolution
        case promptOptimizer = "prompt_optimizer"
        case fastPretreatment = "fast_pretreatment"
        case aigcWatermark = "aigc_watermark"
    }
}

/// Step 1 响应：`POST /v1/video_generation`。
struct MiniMaxVideoTaskCreateResponse: Decodable, Equatable, Sendable {
    let taskId: String?
    let baseResp: MiniMaxBaseResp

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case baseResp = "base_resp"
    }
}

// MARK: - Step 2: Query Video Task

/// Step 2 响应：`GET /v1/video_generation?task_id=...`。
///
/// `status` 可能取值：`Queue` / `Preparing` / `Processing` / `Success` / `Fail`。
/// `fileId` 仅在 `status == "Success"` 时存在。
/// `errorMessage` 仅在失败时存在。
struct MiniMaxVideoTaskQueryResponse: Decodable, Equatable, Sendable {
    let status: String?
    let fileId: String?
    let errorMessage: String?
    let baseResp: MiniMaxBaseResp

    enum CodingKeys: String, CodingKey {
        case status
        case fileId = "file_id"
        case errorMessage = "error_message"
        case baseResp = "base_resp"
    }

    /// 将字符串 status 解码为强类型枚举；非预期值返回 `nil`（调用方按未终态处理）。
    var taskStatus: MiniMaxVideoTaskStatus? {
        guard let status else { return nil }
        return MiniMaxVideoTaskStatus(rawValue: status)
    }

    var isSuccess: Bool { taskStatus == .success }

    var isFailure: Bool { taskStatus == .fail }

    var isTerminal: Bool {
        taskStatus?.isTerminal ?? false
    }
}

// MARK: - Step 3: Retrieve File

/// Step 3 响应：`GET /v1/files/retrieve?file_id=...`。
struct MiniMaxFileRetrieveResponse: Decodable, Equatable, Sendable {
    let file: MiniMaxFileInfo?
    let baseResp: MiniMaxBaseResp

    struct MiniMaxFileInfo: Decodable, Equatable, Sendable {
        let fileId: Int64?
        let bytes: Int64?
        let createdAt: Int64?
        let filename: String?
        let purpose: String?
        let downloadUrl: String?

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case bytes
            case createdAt = "created_at"
            case filename
            case purpose
            case downloadUrl = "download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case file
        case baseResp = "base_resp"
    }

    /// 解析下载 URL。`downloadUrl` 24 小时内有效。
    func resolveDownloadURL() -> URL? {
        guard let raw = file?.downloadUrl, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// 推荐的文件名（用于回传 LLM 时的附件元数据）。
    func preferredFilename() -> String {
        if let name = file?.filename, !name.isEmpty {
            return name
        }
        return "minimax_video.mp4"
    }

    /// 字节数（用于回传给 LLM 时的描述）。
    func byteCount() -> Int64? {
        file?.bytes
    }
}

// MARK: - Errors

/// 视频生成流程中可被 UI 区分的错误类型。
enum MiniMaxVideoError: LocalizedError, Equatable {
    /// 未配置 API Key（通过 `APIKeyStore` 读取失败）。
    case missingAPIKey
    /// 业务错误：HTTP 200 但 `base_resp.status_code != 0`。
    case apiError(code: Int, message: String)
    /// Step 2 任务最终失败（`status == "Fail"`）。
    case taskFailed(message: String)
    /// Step 3 拉取文件元数据时缺少 `download_url`。
    case missingDownloadURL
    /// Step 4 下载二进制失败或非 mp4 内容。
    case downloadFailed(message: String)
    /// 轮询超过上限（默认 3 分钟）。
    case pollingTimeout
    /// 工具被取消（抛 `CancellationError` 之前给出更友好的文案）。
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "MiniMax API Key is not configured. Please add your API key in Lumi settings."
        case .apiError(let code, let message):
            return "MiniMax API error (code=\(code)): \(message)"
        case .taskFailed(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "MiniMax video generation failed."
                : "MiniMax video generation failed: \(trimmed)"
        case .missingDownloadURL:
            return "MiniMax did not return a download URL for the generated video."
        case .downloadFailed(let message):
            return "Failed to download the generated video: \(message)"
        case .pollingTimeout:
            return "MiniMax video generation took too long and was aborted after the polling timeout."
        case .cancelled:
            return "MiniMax video generation was cancelled."
        }
    }
}