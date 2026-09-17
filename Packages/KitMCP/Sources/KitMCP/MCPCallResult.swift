import Foundation

/// 工具调用返回的图片内容（base64 编码数据）。
public struct MCPImageContent: Sendable, Equatable {
    /// base64 编码的图片数据。
    public let base64Data: String
    /// MIME 类型（如 `image/png`）。
    public let mimeType: String

    public init(base64Data: String, mimeType: String) {
        self.base64Data = base64Data
        self.mimeType = mimeType
    }
}

/// 工具调用结果（KitMCP 统一模型，供桥接层映射到 `ToolCallResult`）。
public struct MCPCallResult: Sendable, Equatable {
    /// 拼接后的文本内容（多段 text 用换行连接；非文本内容以可读标记呈现）。
    public let text: String
    /// 图片附件。
    public let images: [MCPImageContent]
    /// 服务器是否标记调用出错（`isError`）。
    public let isError: Bool

    public init(text: String, images: [MCPImageContent] = [], isError: Bool = false) {
        self.text = text
        self.images = images
        self.isError = isError
    }
}
