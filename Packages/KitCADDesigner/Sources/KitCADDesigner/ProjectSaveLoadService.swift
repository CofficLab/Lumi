import Foundation

/// 项目保存/加载服务（`.cadproj` 格式，JSON，基于 Codable）。
///
/// 参考项目持久化范式：JSONEncoder（prettyPrinted + sortedKeys）+ data.write(.atomic)。
///
/// JSON 编解码与磁盘 I/O 全部在后台线程执行（`Task.detached`），调用方在主线程
/// 只负责取快照与等待结果，避免大文档的编码/读写阻塞 UI（见 issue #1176）。
public struct ProjectSaveLoadService: Sendable {
    public init() {}

    /// 将文档编码并写入磁盘。
    ///
    /// 编码与写入在后台线程完成，调用方（主线程）在此期间可以继续渲染与响应事件。
    public func save(document: CADDocument, to url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)
            try data.write(to: url, options: .atomic)
        }.value
    }

    /// 从磁盘读取并解码文档。
    ///
    /// 读取与解码在后台线程完成，避免大文件阻塞主线程。
    public func load(from url: URL) async throws -> CADDocument {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CADDocument.self, from: data)
        }.value
    }

    /// 将文档序列化为 UTF-8 JSON 字符串（用于 AgentTool 返回预览）。
    public func encodeToString(_ document: CADDocument) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
