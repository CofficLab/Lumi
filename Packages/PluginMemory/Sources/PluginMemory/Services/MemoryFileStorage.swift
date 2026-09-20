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
        let sanitized = sanitize(id)
        guard !sanitized.isEmpty else { throw MemoryError.invalidID(id) }

        let directory = directory(for: type, scope: scope, projectPath: projectPath)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("\(sanitized).md")
        let now = Date()

        // 若已存在，保留 createdAt（用同类型目录读取）。
        let existingCreatedAt: Date = {
            if let existing = try? load(id: sanitized, type: type, scope: scope, projectPath: projectPath) {
                return existing.createdAt
            }
            return now
        }()

        let item = MemoryItem(
            id: sanitized,
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
        id: \(sanitized)
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
        let sanitized = sanitize(id)
        let directory = directory(for: type, scope: scope, projectPath: projectPath)
        let fileURL = directory.appendingPathComponent("\(sanitized).md")
        guard fileManager.fileExists(atPath: fileURL.path),
              let raw = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return parse(raw, filePath: fileURL.path, id: sanitized)
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
                return parse(raw, filePath: url.path, id: url.deletingPathExtension().lastPathComponent)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(id: String, scope: MemoryScope, projectPath: String?) throws {
        let sanitized = sanitize(id)
        let directory = directory(for: .project, scope: scope, projectPath: projectPath)
        let fileURL = directory.appendingPathComponent("\(sanitized).md")
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
        return base.appendingPathComponent(sanitize(projectPath))
    }

    private func sanitize(_ string: String) -> String {
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
