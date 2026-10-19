import Foundation

/// 附件预览（`AttachmentPreviewView`）的无障碍标识符。
///
/// 与 `SendActionBarAccessibility` 同理：UI 测试按标识符定位控件，而不是按
/// 本地化文案——AX label 会随 `-AppleLanguages` 变化，按文案定位在非英文
/// 环境下必然失败。预览上的 ✕ 之前只有 `.accessibilityLabel`，没有 identifier，
/// 导致任何想点击它的 UI 测试都只能退化成按文案查找。
///
/// 命名沿用仓库既有惯例，前缀与插件 id 保持一致。
enum AttachmentPreviewAccessibility {
    /// 图片缩略图右上角的移除按钮。
    ///
    /// 每个图片附件一个按钮，值重复——测试按 `element(boundBy:)` 取第 N 个，
    /// 或断言「数量减少了」。
    static let removeImageButton = "lumi.conversation-input.attachment.remove-image"

    /// 文件 chip 上的移除按钮。
    static let removeFileButton = "lumi.conversation-input.attachment.remove-file"
}
