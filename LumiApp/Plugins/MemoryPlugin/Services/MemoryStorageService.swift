import Foundation
import os

/// 记忆文件存储服务
///
/// 负责记忆文件的 CRUD 操作、索引维护和目录管理。
/// 存储路径：`AppConfig.getDBFolderURL()/Memory/`
/// 存储格式：Markdown 文件 + YAML frontmatter，索引文件 `MEMORY.md`
///
/// ## 目录结构
/// ```
/// Memory/
/// ├── global/
/// │   ├── MEMORY.md
/// │   ├── user-role.md
/// │   └── feedback-no-summary.md
/// └── projects/
///     └── <sanitized-path>/
///         ├── MEMORY.md
///         └── project-auth.md
/// ```
actor MemoryStorageService: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = false

    static let shared = MemoryStorageService()

    private let fileManager = FileManager.default
    private let memoryRoot: URL
    private let globalDir: URL
    private let projectsDir: URL
    private let indexFilename = "MEMORY.md"
    private let maxIndexLines = 200
    private let maxIndexBytes = 25 * 1024 // 25KB

    // MARK: - Initialization

    private init() {
        memoryRoot = AppConfig.getDBFolderURL()
            .appendingPathComponent("Memory", isDirectory: true)
        globalDir = memoryRoot
            .appendingPathComponent("global", isDirectory: true)
        projectsDir = memoryRoot
            .appendingPathComponent("projects", isDirectory: true)

        try? fileManager.createDirectory(at: globalDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        if Self.verbose {
            logInfo("记忆存储服务初始化：\(memoryRoot.path)")
        }
    }

    // MARK: - 路径解析

    /// 获取指定作用域的记忆目录
    private func directory(for scope: MemoryScope) -> URL {
        switch scope {
        case .global:
            return globalDir
        case .project(let projectPath):
            let sanitized = sanitizeProjectPath(projectPath)
            return projectsDir
                .appendingPathComponent(sanitized, isDirectory: true)
        }
    }

    /// 将项目路径转换为安全的目录名
    private func sanitizeProjectPath(_ path: String) -> String {
        // 使用路径的 lastPathComponent 作为人类可读标识，加上路径的哈希片段
        let lastComponent = URL(fileURLWithPath: path).lastPathComponent
        let safeName = lastComponent.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .prefix(32)
        // 用简单的字符编码和作为轻量"指纹"
        let hashValue = path.utf8.reduce(0) { ($0 &* 31 + UInt8($1)) }
        return "\(safeName)_\(String(format: "%04x", hashValue))"
    }

    /// 记忆文件路径
    private func memoryFileURL(id: String, scope: MemoryScope) -> URL {
        let dir = directory(for: scope)
        return dir.appendingPathComponent("\(id).md")
    }

    /// 索引文件路径
    private func indexURL(scope: MemoryScope) -> URL {
        let dir = directory(for: scope)
        return dir.appendingPathComponent(indexFilename)
    }

    // MARK: - CRUD

    /// 创建记忆
    ///
    /// - Parameters:
    ///   - id: 记忆 ID（文件名，不含 .md）
    ///   - type: 记忆类型
    ///   - name: 简短名称
    ///   - description: 描述（用于检索相关性判断）
    ///   - content: 记忆正文
    ///   - scope: 作用域
    /// - Returns: 创建的 MemoryItem
    func createMemory(
        id: String,
        type: MemoryType,
        name: String,
        description: String,
        content: String,
        scope: MemoryScope
    ) async throws -> MemoryItem {
        let now = Date()
        let dir = directory(for: scope)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileURL = memoryFileURL(id: id, scope: scope)

        // 构建 Markdown 内容
        let markdown = buildMarkdownContent(
            type: type,
            name: name,
            description: description,
            content: content,
            createdAt: now,
            updatedAt: now
        )

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        let item = MemoryItem(
            id: id,
            filename: "\(id).md",
            type: type,
            name: name,
            description: description,
            content: content,
            createdAt: now,
            updatedAt: now,
            filePath: fileURL.path
        )

        // 更新索引
        try await rebuildIndex(scope: scope)

        if Self.verbose {
            logInfo("创建记忆：\(id) [\(type.rawValue)] 作用域=\(scopeDescription(scope))")
        }

        return item
    }

    /// 读取记忆
    func readMemory(id: String, scope: MemoryScope) async throws -> MemoryItem {
        let fileURL = memoryFileURL(id: id, scope: scope)
        let markdown = try String(contentsOf: fileURL, encoding: .utf8)

        return try parseMarkdownContent(markdown, filePath: fileURL.path, id: id)
    }

    /// 更新记忆
    func updateMemory(
        id: String,
        name: String? = nil,
        description: String? = nil,
        content: String? = nil,
        scope: MemoryScope
    ) async throws -> MemoryItem {
        let existing = try await readMemory(id: id, scope: scope)

        let newName = name ?? existing.name
        let newDescription = description ?? existing.description
        let newContent = content ?? existing.content
        let now = Date()

        let markdown = buildMarkdownContent(
            type: existing.type,
            name: newName,
            description: newDescription,
            content: newContent,
            createdAt: existing.createdAt,
            updatedAt: now
        )

        let fileURL = memoryFileURL(id: id, scope: scope)
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        let item = MemoryItem(
            id: id,
            filename: "\(id).md",
            type: existing.type,
            name: newName,
            description: newDescription,
            content: newContent,
            createdAt: existing.createdAt,
            updatedAt: now,
            filePath: fileURL.path
        )

        try await rebuildIndex(scope: scope)

        if Self.verbose {
            logInfo("更新记忆：\(id)")
        }

        return item
    }

    /// 删除记忆
    func deleteMemory(id: String, scope: MemoryScope) async throws {
        let fileURL = memoryFileURL(id: id, scope: scope)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        try await rebuildIndex(scope: scope)

        if Self.verbose {
            logInfo("删除记忆：\(id)")
        }
    }

    /// 列出所有记忆
    func listMemories(scope: MemoryScope) async -> [MemoryItem] {
        let dir = directory(for: scope)
        let indexFile = indexURL(scope: scope)

        // 读取目录中所有 .md 文件（排除 MEMORY.md）
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dir.path) else {
            return []
        }

        var items: [MemoryItem] = []
        for filename in contents where filename.hasSuffix(".md") && filename != indexFilename {
            let id = String(filename.dropLast(3)) // 去掉 .md
            let fileURL = dir.appendingPathComponent(filename)

            do {
                let markdown = try String(contentsOf: fileURL, encoding: .utf8)
                let item = try parseMarkdownContent(markdown, filePath: fileURL.path, id: id)
                items.append(item)
            } catch {
                if Self.verbose {
                    logInfo("解析记忆文件失败：\(filename) - \(error.localizedDescription)")
                }
            }
        }

        // 按更新时间降序
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - 索引

    /// 读取索引文件内容
    func readIndex(scope: MemoryScope) async -> String {
        let url = indexURL(scope: scope)
        do {
            var content = try String(contentsOf: url, encoding: .utf8)

            // 限制大小
            let lines = content.components(separatedBy: .newlines)
            if lines.count > maxIndexLines {
                content = lines.prefix(maxIndexLines).joined(separator: "\n")
                content += "\n\n> ⚠️ 记忆索引已截断（超过 \(maxIndexLines) 行）。一些记忆未显示。"
            }

            return content
        } catch {
            return ""
        }
    }

    /// 重建索引
    ///
    /// 遍历指定作用域下的所有记忆文件，重建 MEMORY.md。
    func rebuildIndex(scope: MemoryScope) async throws {
        let dir = directory(for: scope)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let memories = await listMemories(scope: scope)

        var lines: [String] = []

        // 标题
        switch scope {
        case .global:
            lines.append("# Global Memory Index")
        case .project(let projectPath):
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            lines.append("# Memory Index: \(projectName)")
        }

        lines.append("")

        if memories.isEmpty {
            lines.append("No memories yet. Use `save_memory` to create your first memory.")
        } else {
            // 按类型分组
            let grouped = Dictionary(grouping: memories) { $0.type }

            let typeOrder: [MemoryType] = [.user, .feedback, .project, .reference]
            for type in typeOrder {
                guard let typeMemories = grouped[type] else { continue }

                // 类型标题
                let typeHeader: String
                switch type {
                case .user: typeHeader = "## User Memories"
                case .feedback: typeHeader = "## Feedback"
                case .project: typeHeader = "## Project Context"
                case .reference: typeHeader = "## References"
                }
                lines.append(typeHeader)
                lines.append("")

                for memory in typeMemories {
                    let staleTag = memory.isStale ? " *(stale, \(memory.ageInDays)d)*" : ""
                    lines.append("- [\(memory.type.rawValue)] **\(memory.name)** — \(memory.description)\(staleTag)")
                }

                lines.append("")
            }
        }

        let indexContent = lines.joined(separator: "\n")
        let url = indexURL(scope: scope)
        try indexContent.write(to: url, atomically: true, encoding: .utf8)

        if Self.verbose {
            logInfo("重建索引：\(memories.count) 条记忆")
        }
    }

    // MARK: - Markdown 解析

    /// 构建 Markdown 内容（含 frontmatter）
    private func buildMarkdownContent(
        type: MemoryType,
        name: String,
        description: String,
        content: String,
        createdAt: Date,
        updatedAt: Date
    ) -> String {
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }()

        return """
        ---
        name: \(name)
        description: \(description)
        type: \(type.rawValue)
        created: \(dateFormatter.string(from: createdAt))
        updated: \(dateFormatter.string(from: updatedAt))
        ---

        \(content)
        """
    }

    /// 解析 Markdown 内容
    private func parseMarkdownContent(_ markdown: String, filePath: String, id: String) throws -> MemoryItem {
        // 查找 frontmatter 结束标记 "\n---\n"
        guard let closingMarkerRange = markdown.range(of: "\n---\n", options: .backwards) else {
            throw MemoryError.invalidFormat("Missing frontmatter end marker")
        }

        // frontmatter 内容：从第 4 个字符（跳过开头的 "---\n"）到结束标记之前
        let frontmatterStart = markdown.index(markdown.startIndex, offsetBy: 4)
        let frontmatter = String(markdown[frontmatterStart..<closingMarkerRange.lowerBound])
        let content = String(markdown[closingMarkerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // 解析 frontmatter 键值对
        let lines = frontmatter.components(separatedBy: .newlines)
        var dict: [String: String] = [:]
        for line in lines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            dict[key] = value
        }

        guard let typeRaw = dict["type"], let type = MemoryType(rawValue: typeRaw) else {
            throw MemoryError.invalidFormat("Missing or invalid 'type' field")
        }

        let name = dict["name"] ?? id
        let description = dict["description"] ?? ""

        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }()

        let createdAt = dateFormatter.date(from: dict["created"] ?? "") ?? Date()
        let updatedAt = dateFormatter.date(from: dict["updated"] ?? "") ?? Date()

        return MemoryItem(
            id: id,
            filename: "\(id).md",
            type: type,
            name: name,
            description: description,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            filePath: filePath
        )
    }

    // MARK: - Helpers

    private func scopeDescription(_ scope: MemoryScope) -> String {
        switch scope {
        case .global: return "global"
        case .project(let path): return "project:\(URL(fileURLWithPath: path).lastPathComponent)"
        }
    }

    private nonisolated func logInfo(_ message: String) {
        AppLogger.core.info("[MemoryStorage][INFO] \(message)")
    }
}

// MARK: - Errors

enum MemoryError: LocalizedError {
    case invalidFormat(String)
    case notFound(String)
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg): return "Invalid memory format: \(msg)"
        case .notFound(let msg): return "Memory not found: \(msg)"
        case .fileSystemError(let msg): return "File system error: \(msg)"
        }
    }
}
