import Foundation

/// 记忆文件存储服务（actor）。
///
/// 目录结构：
/// ```
/// MemoryRoot/
/// ├── global/            # user / feedback 类型
/// │   └── <id>.md
/// └── projects/          # project / reference 类型
///     └── <sanitized>/
///         └── <id>.md
/// ```
public actor MemoryFileStorage {
    private let fileManager = FileManager.default
    private let memoryRoot: URL

    public init(rootURL: URL) {
        self.memoryRoot = rootURL
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: rootURL.appendingPathComponent("global"), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: rootURL.appendingPathComponent("projects"), withIntermediateDirectories: true)
    }

    // MARK: - CRUD

    public func save(
        id: String,
        type: MemoryType,
        name: String,
        description: String,
        content: String,
        scope: MemoryScope,
        projectPath: String?
    ) throws -> MemoryItem {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MemoryError.invalidID(id)
        }
        let fileName = Self.fileName(forID: id)

        let directory = directory(for: type, scope: scope, projectPath: projectPath)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("\(fileName).md")
        let now = Date()

        // 若已存在，保留 createdAt（用同类型目录读取）。
        let existingCreatedAt: Date = {
            if let existing = try? load(id: id, type: type, scope: scope, projectPath: projectPath) {
                return existing.createdAt
            }
            return now
        }()

        let item = MemoryItem(
            id: id,
            type: type,
            name: name,
            description: description,
            content: content,
            createdAt: existingCreatedAt,
            updatedAt: now,
            filePath: fileURL.path
        )

        let body = """
        ---
        id: \(id)
        type: \(type.rawValue)
        name: \(name)
        description: \(description)
        created: \(ISO8601DateFormatter().string(from: existingCreatedAt))
        updated: \(ISO8601DateFormatter().string(from: now))
        ---

        \(content)
        """
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        return item
    }

    public func load(id: String, type: MemoryType, scope: MemoryScope, projectPath: String?) throws -> MemoryItem? {
        let fileName = Self.fileName(forID: id)
        let directory = directory(for: type, scope: scope, projectPath: projectPath)
        let fileURL = directory.appendingPathComponent("\(fileName).md")
        guard fileManager.fileExists(atPath: fileURL.path),
              let raw = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return parse(raw, filePath: fileURL.path, id: id)
    }

    public func list(scope: MemoryScope, projectPath: String?) -> [MemoryItem] {
        let directory = scope == .global
            ? memoryRoot.appendingPathComponent("global")
            : projectsDirectory(for: projectPath)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "md" }
            .compactMap { url in
                guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let id = Self.id(fromFileName: url.deletingPathExtension().lastPathComponent)
                return parse(raw, filePath: url.path, id: id)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(id: String, scope: MemoryScope, projectPath: String?) throws {
        let fileName = Self.fileName(forID: id)
        let directory = directory(for: .project, scope: scope, projectPath: projectPath)
        let fileURL = directory.appendingPathComponent("\(fileName).md")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Private

    private func directory(for type: MemoryType, scope: MemoryScope, projectPath: String?) -> URL {
        if scope == .project {
            return projectsDirectory(for: projectPath)
        }
        // global 作用域下，project/reference 类型也存 global（简化）。
        return memoryRoot.appendingPathComponent("global")
    }

    private func projectsDirectory(for projectPath: String?) -> URL {
        let base = memoryRoot.appendingPathComponent("projects")
        guard let projectPath, !projectPath.isEmpty else { return base }
        return base.appendingPathComponent(sanitizeProjectPath(projectPath))
    }

    /// ID 允许直接出现在文件名中的字符集合。
    private static let allowedIDCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-_."))

    /// 将 Memory ID 一一映射为文件名：允许字符原样保留，其余按 UTF-8 百分号编码。
    ///
    /// 旧实现把所有非法字符统一替换为 `-`，`a b` 与 `a@b` 都会变成 `a-b`，
    /// 后保存的记录会覆盖前者，召回和删除也命中同一文件。百分号编码是可逆映射，
    /// 不同 ID 不会映射到同一个文件名。
    static func fileName(forID id: String) -> String {
        var result = ""
        for scalar in id.unicodeScalars {
            if allowedIDCharacters.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    result += String(format: "%%%02X", byte)
                }
            }
        }
        return result
    }

    /// 从文件名还原 Memory ID（`fileName(forID:)` 的逆映射）。
    static func id(fromFileName fileName: String) -> String {
        fileName.removingPercentEncoding ?? fileName
    }

    private func sanitizeProjectPath(_ string: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./"))
        return string.components(separatedBy: allowed.inverted).joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func parse(_ raw: String, filePath: String, id: String) -> MemoryItem? {
        var name = id
        var type: MemoryType = .project
        var description = ""
        var createdAt = Date()
        var updatedAt = Date()
        var content = raw

        let dateFormatter = ISO8601DateFormatter()

        if raw.hasPrefix("---") {
            let parts = raw.components(separatedBy: "---")
            if parts.count >= 3 {
                let frontmatter = parts[1]
                content = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
                for line in frontmatter.components(separatedBy: .newlines) {
                    let kv = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard kv.count == 2 else { continue }
                    let key = kv[0].trimmingCharacters(in: .whitespaces)
                    let value = kv[1].trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "name": name = value
                    case "type": type = MemoryType(rawValue: value) ?? .project
                    case "description": description = value
                    case "created": createdAt = dateFormatter.date(from: value) ?? createdAt
                    case "updated": updatedAt = dateFormatter.date(from: value) ?? updatedAt
                    default: break
                    }
                }
            }
        }

        return MemoryItem(
            id: id,
            type: type,
            name: name,
            description: description,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            filePath: filePath
        )
    }
}
