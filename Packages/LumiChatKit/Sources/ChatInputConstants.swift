import Foundation

/// 聊天输入相关的常量和工具方法。
public enum ChatInputConstants {
    /// 输入框最小高度。
    public static let inputMinHeight: CGFloat = 64

    /// 支持的图片扩展名。
    public static let imagePathExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
    ]

    /// 检查 URL 是否为聊天支持的图片文件。
    public static func isChatImageFileURL(_ url: URL) -> Bool {
        imagePathExtensions.contains(url.pathExtension.lowercased())
    }
}