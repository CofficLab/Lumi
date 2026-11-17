import Foundation

/// 目标地图在磁盘上的状态。
public enum MindMapDiskState {
    /// 文件存在且解码成功。
    case loaded(MindMap)
    /// 目录下没有匹配该 id 的文件。
    case missing
    /// 文件存在但读取或解码失败（损坏）。
    case unreadable
}

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

    /// 按文件名中的 id 前缀定位单个导图并读取其当前磁盘状态。
    ///
    /// 写前同步只需要对齐将被写回的那一个文件；全量 `loadAll` 会把目录下
    /// 每个文件都读盘解码，单次节点编辑也要付出全部导图的代价（#1190）。
    public static func diskState(forMapID id: String, storagePath: String) -> MindMapDiskState {
        guard !storagePath.isEmpty else { return .missing }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        guard
            let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return .missing }
        let suffix = "-\(id.prefix(8)).json"
        guard
            let url = urls.first(where: {
                $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.hasSuffix(suffix)
            })
        else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .unreadable }
        guard let map = try? decoder.decode(MindMap.self, from: data) else { return .unreadable }
        return .loaded(map)
    }

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
    ///
    /// 只有确认文件已删除才正常返回；任何一步删不掉都会抛错，调用方不得据此更新内存列表。
    public static func delete(_ map: MindMap, storagePath: String) throws {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        let primary = directory.appendingPathComponent(fileName(for: map))
        if fileManager.fileExists(atPath: primary.path) {
            try fileManager.removeItem(at: primary)
            return
        }
        // 目录不存在时该文件不可能存在，视为已经删除。
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let suffix = "-\(map.id.prefix(8)).json"
        for url in urls where url.pathExtension.lowercased() == "json" && url.lastPathComponent.hasSuffix(suffix) {
            try fileManager.removeItem(at: url)
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
