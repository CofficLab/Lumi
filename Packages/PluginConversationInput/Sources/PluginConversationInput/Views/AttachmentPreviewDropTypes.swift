import UniformTypeIdentifiers

/// 附件预览区（拖放落点）所声明的拖放类型。
///
/// 单独成文件是为了让「声明了什么」成为**单一事实来源**：视图的
/// `.onDrop(of:)` 与单测断言引用同一份常量，两边不会各写一份后悄悄漂移。
enum AttachmentPreviewDropTypes {
    /// 预览区只接受文件拖放。
    ///
    /// - Important: **不要**在这里加入 `.plainText` / `.text` / `.image`。
    ///
    ///   SwiftUI 会按 `.onDrop(of:)` 声明的类型给 `NSItemProvider` 做
    ///   **降级**：只保留能匹配声明的表示，其余表示被丢弃。实测：
    ///
    ///   | 拖入 | 声明含 `.image` / `.plainText` | 只声明 `.fileURL` |
    ///   |------|------------------------------|------------------|
    ///   | PNG | `public.png`（无路径）→ 失败 | `public.file-url` → 成功 |
    ///   | TXT | `public.plain-text`（无路径）→ 失败 | `public.file-url` → 成功 |
    ///   | PDF | `public.file-url` → 成功 | `public.file-url` → 成功 |
    ///
    ///   路径一旦被降级丢掉就无法恢复，`DroppedItemResolver` 拿不到 URL，
    ///   拖放随即静默失败。
    ///
    ///   代价：纯文本拖入（编辑器里选中的路径）不再被预览区接受 —— 那条路
    ///   走输入框即可（输入框是 AppKit `NSTextView`，直接从 `NSPasteboard`
    ///   读 `NSURL`，不受这里的降级影响）。预览区是附件区，只接文件。
    static let declared: [UTType] = [.fileURL]
}
