import Foundation

/// 项目保存/加载服务（`.cadproj` 格式，JSON，基于 Codable）。
///
/// 参考项目持久化范式：JSONEncoder（prettyPrinted + sortedKeys）+ data.write(.atomic)。
public struct ProjectSaveLoadService {
    public init() {}

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func save(document: CADDocument, to url: URL) throws {
        let encoder = makeEncoder()
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> CADDocument {
        let data = try Data(contentsOf: url)
        let decoder = makeDecoder()
        return try decoder.decode(CADDocument.self, from: data)
    }

    /// 将文档序列化为 UTF-8 JSON 字符串（用于 AgentTool 返回预览）。
    public func encodeToString(_ document: CADDocument) throws -> String {
        let data = try makeEncoder().encode(document)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
