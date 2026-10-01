import Foundation

/// 附件元数据。正文附件流经 `MailCoreAdapter` 落盘到插件数据目录后，
/// `localFileURL` 指向本地文件；未落盘时 `data` 携带内存数据。
public struct MailAttachment: Sendable, Codable, Hashable, Identifiable {
    public var filename: String
    public var mimeType: String
    public var size: Int64
    /// 已落盘的附件本地路径（`fetchBody` 默认落盘，避免大附件占内存）
    public var localFileURL: String?
    /// 内联数据（仅 `fetchBody(includeInlineData:)` 请求时非 nil）
    public var data: Data?

    public init(
        filename: String,
        mimeType: String,
        size: Int64,
        localFileURL: String? = nil,
        data: Data? = nil
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.localFileURL = localFileURL
        self.data = data
    }

    public var id: String {
        "\(filename)-\(mimeType)-\(size)"
    }
}
