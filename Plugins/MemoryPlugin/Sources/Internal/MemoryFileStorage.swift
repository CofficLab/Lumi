import Foundation
import os
import SuperLogKit

/// 记忆文件存储服务
///
/// 负责记忆文件的 CRUD 操作、索引维护和目录管理。
///
/// ## 目录结构
/// ```
/// MemoryRoot/
/// ├── global/
/// │   ├── MEMORY.md
/// │   ├── user-role.md
/// │   └── feedback-no-summary.md
/// ── projects/
///     └── <sanitized-path>/
///         ├── MEMORY.md
///         └── project-auth.md
/// ```
public actor MemoryFileStorage: SuperLog {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.memory.storage")

    private let fileManager = FileManager.default
    private let memoryRoot: URL
    private let globalDir: URL
    private let projectsDir: URL
    private let indexFilename = "MEMORY.md"
    private let maxIndexLines = 200
    private let verbose: Bool

    // MARK: - Initialization

    /// 创建存储服务实例
    ///
    /// - Parameters:
    ///   - rootURL: 记忆存储的根目录 URL
    ///   - verbose: 是否启用详细日志
    public init(rootURL: URL, verbose: Bool = false) {
        self.memoryRoot = rootURL
        self.verbose = verbose
        self.globalDir = memoryRoot
            .appendingPathComponent("global", isDirectory: true)
        self.projectsDir = memoryRoot
            .appendingPathComponent("projects", isDirectory: true)

        try? fileManager.createDirectory(at: globalDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        if verbose {
            Self.logger.info("\(Self.t)记忆存储服务初始化：\(rootURL.path)")
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
        Self.sanitizeProjectPath(path)
    }

    /// 将项目路径转换为安全的、唯一的目录名。
    ///
    /// 取路径末段作为人类可读标识，再追加一段基于完整路径的稳定哈希作为"指纹"，
    /// 避免不同项目仅因末段同名而写入同一目录。
    ///
    /// - Note: 历史实现将哈希折叠进 `UInt8`（仅 256 种取值），不同路径极易碰撞，
    ///   导致跨项目记忆串扰；现已改用 FNV-1a 64 位哈希。
    package static func sanitizeProjectPath(_ path: String) -> String {
        // 使用路径的 lastPathComponent 作为人类可读标识
        let lastComponent = URL(fileURLWithPath: path).lastPathComponent
        let safeName = lastComponent.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .prefix(32)
        // FNV-1a 64 位哈希，比旧版 UInt8 求和碰撞率低得多
        let hashValue = path.utf8.reduce(UInt64(0xcbf29ce484222325)) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return "\(safeName)_\(String(format: "%016llx", hashValue))"
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
    public func createMemory(
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

        if verbose {
            Self.logger.info("\(Self.t)创建记忆：\(id) [\(type.rawValue)] 作用域=\(self.scopeDescription(scope))")
        }

        return item
    }

    /// 读取记忆
    public func readMemory(id: String, scope: MemoryScope) async throws -> MemoryItem {
        let fileURL = memoryFileURL(id: id, scope: scope)
        let markdown: String
        do {
            markdown = try readTextFile(fileURL).content
        } catch CocoaError.fileReadNoSuchFile {
            throw MemoryError.notFound("'\(id)' in \(scopeDescription(scope))")
        }
        return try parseMarkdownContent(markdown, filePath: fileURL.path, id: id)
    }

    /// 更新记忆
    public func updateMemory(
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
        let encoding = (try? readTextFile(fileURL).encoding) ?? .utf8
        try markdown.write(to: fileURL, atomically: true, encoding: encoding)

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

        if verbose {
            Self.logger.info("\(Self.t)更新记忆：\(id)")
        }

        return item
    }

    /// 删除记忆
    public func deleteMemory(id: String, scope: MemoryScope) async throws {
        let fileURL = memoryFileURL(id: id, scope: scope)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        try await rebuildIndex(scope: scope)

        if verbose {
            Self.logger.info("\(Self.t)删除记忆：\(id)")
        }
    }

    /// 列出所有记忆
    public func listMemories(scope: MemoryScope) async -> [MemoryItem] {
        let dir = directory(for: scope)

        // 读取目录中所有 .md 文件（排除 MEMORY.md）
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dir.path) else {
            return []
        }

        var items: [MemoryItem] = []
        for filename in contents where filename.hasSuffix(".md") && filename != indexFilename {
            let id = String(filename.dropLast(3)) // 去掉 .md
            let fileURL = dir.appendingPathComponent(filename)

            do {
                let markdown = try readTextFile(fileURL).content
                let item = try parseMarkdownContent(markdown, filePath: fileURL.path, id: id)
                items.append(item)
            } catch {
                if verbose {
                    Self.logger.info("\(Self.t)解析记忆文件失败：\(filename) - \(error.localizedDescription)")
                }
            }
        }

        // 按更新时间降序
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - 索引

    /// 读取索引文件内容
    public func readIndex(scope: MemoryScope) async -> String {
        let url = indexURL(scope: scope)
        do {
            var content = try readTextFile(url).content

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
    public func rebuildIndex(scope: MemoryScope) async throws {
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
                    let staleTag = memory.isStale(thresholdDays: 7) ? " *(stale, \(memory.ageInDays)d)*" : ""
                    lines.append("- [\(memory.type.rawValue)] **\(memory.name)** — \(memory.description)\(staleTag)")
                }

                lines.append("")
            }
        }

        let indexContent = lines.joined(separator: "\n")
        let url = indexURL(scope: scope)
        try indexContent.write(to: url, atomically: true, encoding: .utf8)

        if verbose {
            Self.logger.info("\(Self.t)重建索引：\(memories.count) 条记忆")
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
        let openingMarker = "---\n"
        guard markdown.hasPrefix(openingMarker) else {
            throw MemoryError.invalidFormat("Missing frontmatter start marker")
        }

        let frontmatterStart = markdown.index(markdown.startIndex, offsetBy: openingMarker.count)

        // 查找 frontmatter 结束标记 "\n---\n"
        guard let closingMarkerRange = markdown.range(of: "\n---\n", range: frontmatterStart..<markdown.endIndex) else {
            throw MemoryError.invalidFormat("Missing frontmatter end marker")
        }

        // frontmatter 内容：跳过开头的 "---\n" 到结束标记之前
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

    private func readTextFile(_ url: URL) throws -> (content: String, encoding: String.Encoding) {
        var encoding = String.Encoding.utf8
        let content = try String(contentsOf: url, usedEncoding: &encoding)
        return (content, encoding)
    }

    private func scopeDescription(_ scope: MemoryScope) -> String {
        switch scope {
        case .global: return "global"
        case .project(let path): return "project:\(URL(fileURLWithPath: path).lastPathComponent)"
        }
    }
}
