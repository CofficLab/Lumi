import Foundation

/// 与作用域无关的纯文件系统文档存储：所有方法接收一个 `storagePath`（目录路径），
/// 在其下读写 `<safeTitle>-<id-prefix>.json`。不持有任何状态，便于按作用域复用。
public enum IconDocumentFileStore {
    private static nonisolated(unsafe) let fileManager = FileManager.default
    private static nonisolated(unsafe) let fileService = IconDocumentFileService()

    /// 列出指定目录下的全部图标文档（按文件名排序）。
    public static func loadAll(storagePath: String) -> [IconDocument] {
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
            .compactMap { try? fileService.load(from: $0) }
    }

    /// 将文档写入指定目录（原子写），自动创建目录。
    public static func save(_ document: IconDocument, storagePath: String) throws {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileService.save(document: document, to: directory.appendingPathComponent(fileName(for: document)))
    }

    /// 删除指定目录下属于该文档的文件。优先按文件名删除，失败时按 id 前缀扫描兜底，
    /// 以兼容标题被重命名后残留的旧文件。
    public static func delete(_ document: IconDocument, storagePath: String) {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        let primary = directory.appendingPathComponent(fileName(for: document))
        if fileManager.fileExists(atPath: primary.path) {
            try? fileManager.removeItem(at: primary)
            return
        }
        // 兜底：扫描 id 前缀。
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        let suffix = "-\(document.id.prefix(8)).json"
        for url in urls where url.pathExtension.lowercased() == "json" && url.lastPathComponent.hasSuffix(suffix) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// 与文档标题与 id 派生的稳定文件名。
    public static func fileName(for document: IconDocument) -> String {
        let safe = document.title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = safe.isEmpty ? "icon" : safe
        return "\(base)-\(document.id.prefix(8)).json"
    }
}
