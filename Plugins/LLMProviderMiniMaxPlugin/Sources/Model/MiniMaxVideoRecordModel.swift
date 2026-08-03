import Foundation
import SwiftData

/// MiniMax 视频生成记录的持久化模型。
///
/// 由 `MiniMaxVideoRecordStore` 使用 SwiftData 持久化到
/// `storage.pluginDataDirectory(for: "LLMProviderMiniMax")` 下的 SQLite 文件。
///
/// 每条记录对应一次视频生成请求，从任务提交到最终成功/失败全生命周期。
@Model
final class MiniMaxVideoRecordModel {
    /// 本地唯一标识。
    @Attribute(.unique) var id: String
    /// MiniMax 返回的任务 ID（Step 1 响应）。
    var taskID: String?
    /// MiniMax 返回的文件 ID（Step 2 成功响应）。
    var fileID: String?
    /// 用户输入的 prompt。
    var prompt: String
    /// 使用的模型名称（如 "MiniMax-Hailuo-2.3"）。
    var model: String
    /// 视频时长（秒）：6 或 10。
    var duration: Int
    /// 视频分辨率：720P / 768P / 1080P。
    var resolution: String
    /// 是否启用 prompt 优化。
    var promptOptimizer: Bool
    /// 是否启用快速预处理。
    var fastPretreatment: Bool
    /// 是否添加 AIGC 水印。
    var aigcWatermark: Bool
    /// 任务最终状态：pending / generating / success / failed / cancelled。
    var status: String
    /// 下载链接（MiniMax 提供，24 小时有效）。
    var downloadURL: String?
    /// 推荐文件名。
    var fileName: String?
    /// 文件字节数。
    var byteCount: Int64?
    /// 失败时的错误信息。
    var errorMessage: String?
    /// 记录创建时间（任务提交时刻）。
    var createdAt: Date
    /// 任务完成时间（成功或失败的终态时刻）。
    var completedAt: Date?
    /// 下载链接过期时间（createdAt + 24h 近似值）。
    var downloadURLExpiresAt: Date?

    init(
        id: String = UUID().uuidString,
        taskID: String? = nil,
        fileID: String? = nil,
        prompt: String,
        model: String,
        duration: Int,
        resolution: String,
        promptOptimizer: Bool,
        fastPretreatment: Bool,
        aigcWatermark: Bool,
        status: String,
        downloadURL: String? = nil,
        fileName: String? = nil,
        byteCount: Int64? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        downloadURLExpiresAt: Date? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.fileID = fileID
        self.prompt = prompt
        self.model = model
        self.duration = duration
        self.resolution = resolution
        self.promptOptimizer = promptOptimizer
        self.fastPretreatment = fastPretreatment
        self.aigcWatermark = aigcWatermark
        self.status = status
        self.downloadURL = downloadURL
        self.fileName = fileName
        self.byteCount = byteCount
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.downloadURLExpiresAt = downloadURLExpiresAt
    }
}

// MARK: - MiniMaxVideoRecordStatus

/// 视频生成记录的状态枚举（本地持久化用，与 MiniMax API 的 taskStatus 解耦）。
enum MiniMaxVideoRecordStatus: String, Sendable {
    /// 任务已提交，等待 MiniMax 处理。
    case pending
    /// 正在生成中（轮询阶段）。
    case generating
    /// 生成成功，已获取下载链接。
    case success
    /// 生成失败。
    case failed
    /// 用户取消。
    case cancelled
}
