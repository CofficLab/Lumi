import Foundation

/// HTML 卡片的结构化载荷。
///
/// 这份数据随消息一起落库（JSON 化后写入 `Message.metadata`），
/// 因此渲染器重启后仍能还原出完整的卡片，而不必依赖内存里的临时状态。
///
/// ## 为什么载荷里是路径而不是 HTML 本身
///
/// `Message.metadata` 的类型是 `[String: String]`，而 LLM 画出来的界面
/// 可能有几十 KB。把整份 HTML 塞进 metadata 会撑爆消息表，也让每轮
/// 上下文的解码成本变高。
///
/// 因此载荷只记录**文件位置**：
/// - `htmlPath`：落盘的 HTML 源文件，渲染器用它加载活页面；
/// - `snapshotPath`：预先渲染好的 PNG 快照，列表里默认展示它。
public struct HTMLCanvasPayload: Codable, Sendable, Equatable {
    /// 卡片标题。为空时渲染器回退到本地化默认值。
    public let title: String
    /// 落盘的 HTML 文件绝对路径。
    public let htmlPath: String
    /// 预渲染 PNG 快照的绝对路径。
    ///
    /// 为空表示快照渲染失败，渲染器回退到直接加载 HTML。
    public let snapshotPath: String
    /// 设计画布宽度（CSS 逻辑像素）。
    public let width: Double
    /// 设计画布高度（CSS 逻辑像素）。
    public let height: Double

    public init(
        title: String = "",
        htmlPath: String,
        snapshotPath: String = "",
        width: Double,
        height: Double
    ) {
        self.title = title
        self.htmlPath = htmlPath
        self.snapshotPath = snapshotPath
        self.width = width
        self.height = height
    }

    /// 标题回退：为空时由渲染器填入本地化默认值。
    public var displayTitle: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// HTML 文件是否存在。
    ///
    /// 卡片是持久化在消息里的：LLM 调用工具时文件还在，但用户过几天
    /// 再回看这条消息时，插件数据目录可能已被清理。
    public var hasHTMLFile: Bool {
        let trimmed = htmlPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: trimmed)
    }

    /// 快照文件是否存在。
    public var hasSnapshot: Bool {
        let trimmed = snapshotPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: trimmed)
    }

    /// 画布尺寸（CSS 逻辑像素）。
    ///
    /// 缺省值与工具的缺省一致：LLM 没指定尺寸时用 800×600。
    public var canvasSize: CGSize {
        CGSize(width: width, height: height)
    }
}
