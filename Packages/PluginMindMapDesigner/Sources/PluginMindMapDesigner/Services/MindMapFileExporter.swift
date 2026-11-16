import Foundation

/// 思维导图导出：编码 + 原子写入。
///
/// 全部成员 nonisolated，可在后台执行器上运行，避免在主线程同步编码整张图
/// 并写文件而冻结 UI（#1202）。调用方负责主线程上的保存面板与进度态转换。
public enum MindMapFileExporter {
    public enum Format: String, Sendable {
        case markdown
        case json

        public var fileExtension: String {
            switch self {
            case .markdown: "md"
            case .json: "json"
            }
        }
    }

    /// 把思维导图编码为导出字节。Markdown 走大纲 codec，JSON 走稳定排序的 ISO8601 编码。
    public static func encode(_ map: MindMap, format: Format) throws -> Data {
        switch format {
        case .markdown:
            return MindMapMarkdownCodec.encode(map).data(using: .utf8) ?? Data()
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(map)
        }
    }

    /// 编码并原子写入目标文件。可在 detached 后台任务中调用。
    public static func write(_ map: MindMap, format: Format, to url: URL) throws {
        let data = try encode(map, format: format)
        try data.write(to: url, options: .atomic)
    }
}