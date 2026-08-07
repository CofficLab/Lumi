import Foundation
import SwiftData

/// MiniMax 图片生成记录的持久化模型。
///
/// 由 `MiniMaxImageRecordStore` 使用 SwiftData 持久化到
/// `storage.pluginDataDirectory(for: "LLMProviderMiniMax")` 下的 SQLite 文件。
///
/// 每条记录对应一次图片生成请求，从任务提交到最终成功/失败全生命周期。
@Model
final class MiniMaxImageRecordModel {
    /// 本地唯一标识。
    @Attribute(.unique) var id: String
    /// MiniMax 返回的任务 ID。
    var taskID: String?
    /// 用户输入的 prompt。
    var prompt: String
    /// 使用的模型名称（如 "image-01" 或 "image-01-live"）。
    var model: String
    /// 人物主体参考（图生图），JSON 字符串数组（如 `[{"type":"character","image_file":"https://..."}]`）。
    var subjectReference: String?
    /// 画风类型（如 "漫画"、"水彩"），仅 image-01-live 生效。
    var styleType: String?
    /// 画风权重，仅 image-01-live 生效。
    var styleWeight: Float?
    /// 图像宽高比（如 "1:1"、"16:9"）。
    var aspectRatio: String?
    /// 图像宽度（像素），仅 image-01 生效。
    var width: Int?
    /// 图像高度（像素），仅 image-01 生效。
    var height: Int?
    /// 请求生成的图片数量。
    var n: Int
    /// 是否启用 prompt 优化。
    var promptOptimizer: Bool
    /// 是否添加 AIGC 水印。
    var aigcWatermark: Bool
    /// 任务最终状态：pending / success / failed / cancelled。
    var status: String
    /// 成功生成的图片数量。
    var successCount: Int
    /// 因内容安全检查失败的图片数量。
    var failedCount: Int
    /// 生成的图片 URL 列表（JSON 字符串数组，24 小时有效）。
    var imageURLs: String?
    /// 失败时的错误信息。
    var errorMessage: String?
    /// 记录创建时间（任务提交时刻）。
    var createdAt: Date
    /// 任务完成时间（成功或失败的终态时刻）。
    var completedAt: Date?
    /// 图片 URL 过期时间（createdAt + 24h 近似值）。
    var imageURLExpiresAt: Date?

    init(
        id: String = UUID().uuidString,
        taskID: String? = nil,
        prompt: String,
        model: String,
        subjectReference: String? = nil,
        styleType: String? = nil,
        styleWeight: Float? = nil,
        aspectRatio: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        n: Int,
        promptOptimizer: Bool,
        aigcWatermark: Bool,
        status: String,
        successCount: Int = 0,
        failedCount: Int = 0,
        imageURLs: String? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        imageURLExpiresAt: Date? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.prompt = prompt
        self.model = model
        self.subjectReference = subjectReference
        self.styleType = styleType
        self.styleWeight = styleWeight
        self.aspectRatio = aspectRatio
        self.width = width
        self.height = height
        self.n = n
        self.promptOptimizer = promptOptimizer
        self.aigcWatermark = aigcWatermark
        self.status = status
        self.successCount = successCount
        self.failedCount = failedCount
        self.imageURLs = imageURLs
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.imageURLExpiresAt = imageURLExpiresAt
    }
}
