import Foundation

/// 与作用域无关的纯文件系统思维导图存储。
///
/// 所有方法接收一个 `storagePath`（目录路径），在其下读写
/// `<safeTitle>-<id-prefix>.json`。不持有任何状态，便于按作用域复用。
public enum MindMapFileStore {
    private static nonisolated(unsafe) let fileManager = FileManager.default

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// 列出指定目录下的全部思维导图（按文件名排序）。
    public static func loadAll(storagePath: String) -> [MindMap] {
        guard !storagePath.isEmpty else { return [] }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        guard
            let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { url -> MindMap? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(MindMap.self, from: data)
            }
    }

    /// 将思维导图写入指定目录（原子写），自动创建目录。
    public static func save(_ map: MindMap, storagePath: String) throws {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(map)
        try data.write(to: directory.appendingPathComponent(fileName(for: map)), options: .atomic)
    }

    /// 删除指定目录下属于该思维导图的文件。优先按文件名删除，失败时按 id 前缀扫描兜底，
    /// 以兼容标题被重命名后残留的旧文件。
    public static func delete(_ map: MindMap, storagePath: String) {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        let primary = directory.appendingPathComponent(fileName(for: map))
        if fileManager.fileExists(atPath: primary.path) {
            try? fileManager.removeItem(at: primary)
            return
        }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        let suffix = "-\(map.id.prefix(8)).json"
        for url in urls where url.pathExtension.lowercased() == "json" && url.lastPathComponent.hasSuffix(suffix) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// 与思维导图标题和 id 派生的稳定文件名。
    public static func fileName(for map: MindMap) -> String {
        let safe = map.title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = safe.isEmpty ? "mindmap" : safe
        return "\(base)-\(map.id.prefix(8)).json"
    }
}
