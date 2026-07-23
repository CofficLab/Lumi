import Foundation

/// 任意文件附件(与图片附件 `LumiImageAttachment` 并行的另一条链路)。
///
/// 设计动机:聊天附件历史上只支持图片(base64 + 多模态管线)。为了让用户能附加
/// **任意文件**到对话,引入此类型,走并行链路:
/// - 文本类文件(.swift/.json/.md/.txt/text/* 等可 UTF-8 解码的)→ `textContent` 非空,
///   发送时把正文以围栏块注入用户消息文本(所有 provider 通用)。
/// - 二进制文件(.zip/.pdf/.docx 等)→ `textContent` 为 nil,仅作为可见 chip + 占位标注。
///
/// 与 `LumiImageAttachment` 的关系:两者**独立**存在各自的挂起池与 metadata key,
/// 互不影响,保持图片多模态管线零改动。
public struct LumiFileAttachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let mimeType: String
    /// 原始文件字节(经 base64 编码)。用于体积展示与未来扩展(如文件 content part)。
    public let base64Data: String
    /// 文本类文件 UTF-8 解码后的正文;二进制文件为 nil。
    public let textContent: String?

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        base64Data: String,
        textContent: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.textContent = textContent
    }
}
