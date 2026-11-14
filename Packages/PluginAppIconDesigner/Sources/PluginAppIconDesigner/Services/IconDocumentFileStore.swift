import Foundation

/// 与作用域无关的纯文件系统文档存储：所有方法接收一个 `storagePath`（目录路径），
/// 在其下读写 `<safeTitle>-<id-prefix>.json`。不持有任何状态，便于按作用域复用。
public enum IconDocumentFileStore {
    private static nonisolated(unsafe) let fileManager = FileManager.default
    private static nonisolated(unsafe) let fileService = IconDocumentFileService()

    /// 列出指定目录下的全部图标文档（按文件名排序，同一 ID 仅保留最新修订）。
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

        let sortedURLs = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        // 标题重命名可能让同一 ID 残留多个文件，仅保留 updatedAt 最新的修订，
        // 避免列表出现重复 ID；无重复时输出仍与文件名排序一致（#292）。
        var bestByID: [String: (order: Int, document: IconDocument)] = [:]
        for (order, url) in sortedURLs.enumerated() {
            guard let document = try? fileService.load(from: url) else { continue }
            if let existing = bestByID[document.id], existing.document.updatedAt >= document.updatedAt {
                continue
            }
            bestByID[document.id] = (order, document)
        }
        return bestByID.values.sorted { $0.order < $1.order }.map(\.document)
    }

    /// 将文档写入指定目录（原子写），自动创建目录。
    public static func save(_ document: IconDocument, storagePath: String) throws {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileService.save(document: document, to: directory.appendingPathComponent(fileName(for: document)))
    }

    /// 删除指定目录下属于该文档的全部文件。按 id 前缀扫描，确保标题重命名后
    /// 残留的旧文件一并清除，而不是只删当前标题的主文件。
    public static func delete(_ document: IconDocument, storagePath: String) {
        guard !storagePath.isEmpty else { return }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        // 只删主文件会让旧标题版本在重载后复活，故清除该 ID 的全部派生文件（#292）。
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
