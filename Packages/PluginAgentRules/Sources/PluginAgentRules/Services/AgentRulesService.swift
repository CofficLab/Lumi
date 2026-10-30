import Foundation
import KitAgentTool
import ProviderAgentRules

/// Agent 规则服务
///
/// 负责管理项目 `.lumi/rules` 目录中的规则文档。
///
/// **写入**只落 `.lumi/rules`；**读取**同时兼容历史目录 `.agent/rules`
/// （`.lumi` 优先，同名以 `.lumi` 为准），旧项目无需迁移即可继续使用。
public actor AgentRulesService {
    public static let shared = AgentRulesService()

    /// 规则文档所在的子目录名。
    private static let component = "rules"

    /// 获取写入目标规则目录路径（`.lumi/rules`）。
    private func getRulesDirectoryURL(for projectPath: String) -> URL {
        ProjectConfigDirectory.writeURL(projectPath: projectPath, component: Self.component)
    }

    /// 获取读取候选规则目录路径（`.lumi/rules` 优先，`.agent/rules` 兜底）。
    private func getRulesDirectoryURLs(for projectPath: String) -> [URL] {
        ProjectConfigDirectory.readURLs(projectPath: projectPath, component: Self.component)
    }

    /// 获取规则文档列表
    ///
    /// 合并 `.lumi/rules` 与历史目录 `.agent/rules`：同名文档以 `.lumi` 为准，
    /// `.agent` 中的其余文档补充进来。
    public func listRules(projectPath: String) async throws -> [AgentRuleMetadata] {
        let directoryURLs = getRulesDirectoryURLs(for: projectPath)

        // 两个目录都不存在时才算「目录缺失」。
        guard directoryURLs.contains(where: {
            FileManager.default.fileExists(atPath: $0.path())
        }) else {
            throw AgentRulesError.directoryNotFound(directoryURLs[0].path())
        }

        // 按文件名去重，`.lumi` 优先。
        var seenFilenames = Set<String>()
        var rules: [AgentRuleMetadata] = []

        for directoryURL in directoryURLs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey
                ],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "md" {
                let filename = file.lastPathComponent
                guard !seenFilenames.contains(filename) else { continue }
                seenFilenames.insert(filename)

                let resourceValues = try file.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey
                ])

                let fileSize = resourceValues.fileSize ?? 0
                let modifiedAt = resourceValues.contentModificationDate ?? Date()
                _ = resourceValues.creationDate ?? Date()

                // 读取文件内容以提取标题和描述
                let content = try readTextFile(at: file)
                let (title, description) = extractTitleAndDescription(from: content)

                let id = filename.replacingOccurrences(of: ".md", with: "")

                let rule = AgentRuleMetadata(
                    id: id,
                    filename: filename,
                    title: title,
                    description: description,
                    fileSize: Int64(fileSize),
                    modifiedAt: modifiedAt,
                    filePath: file.path()
                )

                rules.append(rule)
            }
        }

        // 按修改时间排序（最新的在前）
        rules.sort { $0.modifiedAt > $1.modifiedAt }

        return rules
    }

    /// 加载项目规则的统一 Provider 表示，供 LLM 注入和插件规则合并使用。
    ///
    /// 合并 `.lumi/rules` 与历史目录 `.agent/rules`（同名以 `.lumi` 为准）。
    /// 项目规则目录不存在或单个文件读取失败时返回可用的部分结果，避免规则
    /// 管理目录问题阻断正常对话。
    public func loadRuleDefinitions(projectPath: String) -> [AgentRuleDefinition] {
        let directoryURLs = getRulesDirectoryURLs(for: projectPath)

        var seenIds = Set<String>()
        var definitions: [AgentRuleDefinition] = []

        for directoryURL in directoryURLs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for file in files.filter({ $0.pathExtension == "md" })
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let id = file.deletingPathExtension().lastPathComponent
                guard !seenIds.contains(id) else { continue }
                guard let content = try? readTextFile(at: file) else { continue }
                seenIds.insert(id)

                let (title, description) = extractTitleAndDescription(from: content)
                definitions.append(
                    AgentRuleDefinition(
                        id: id,
                        title: title,
                        description: description,
                        content: content,
                        version: "project"
                    )
                )
            }
        }

        return definitions
    }

    /// 读取规则文档内容
    ///
    /// 先查 `.lumi/rules`，未命中再查历史目录 `.agent/rules`。
    public func readRule(projectPath: String, filename: String) async throws -> AgentRule {
        let directoryURLs = getRulesDirectoryURLs(for: projectPath)

        guard let fileURL = directoryURLs
            .map({ $0.appending(path: filename) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path()) })
        else {
            throw AgentRulesError.fileNotFound(
                directoryURLs[0].appending(path: filename).path()
            )
        }

        // 读取文件内容
        let content = try readTextFile(at: fileURL)

        // 获取文件属性
        let resourceValues = try fileURL.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey
        ])

        let fileSize = resourceValues.fileSize ?? 0
        let modifiedAt = resourceValues.contentModificationDate ?? Date()
        let createdAt = resourceValues.creationDate ?? Date()

        // 提取标题和描述
        let (title, description) = extractTitleAndDescription(from: content)

        let id = filename.replacingOccurrences(of: ".md", with: "")

        return AgentRule(
            id: id,
            filename: filename,
            title: title,
            description: description,
            fileSize: Int64(fileSize),
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            filePath: fileURL.path(),
            content: content
        )
    }

    /// 创建新的规则文档
    public func createRule(
        projectPath: String,
        filename: String,
        title: String,
        content: String
    ) async throws -> AgentRule {
        let directoryURL = getRulesDirectoryURL(for: projectPath)

        // 确保目录存在，不存在则创建
        if !FileManager.default.fileExists(atPath: directoryURL.path()) {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        // 确保文件名以 .md 结尾
        let finalFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"
        let fileURL = directoryURL.appending(path: finalFilename)

        // 检查文件是否已存在
        guard !FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw AgentRulesError.fileAlreadyExists(fileURL.path())
        }

        // 准备文件内容（添加标题）
        let finalContent: String
        if content.isEmpty {
            finalContent = "# \(title)\n\n"
        } else if content.hasPrefix("# ") {
            finalContent = content
        } else {
            finalContent = "# \(title)\n\n\(content)"
        }

        // 写入文件
        try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let now = Date()
        let id = finalFilename.replacingOccurrences(of: ".md", with: "")

        return AgentRule(
            id: id,
            filename: finalFilename,
            title: title,
            description: extractDescription(from: finalContent),
            fileSize: Int64(finalContent.count),
            createdAt: now,
            modifiedAt: now,
            filePath: fileURL.path(),
            content: finalContent
        )
    }

    // MARK: - Private Helpers

    /// 读取用户编辑的规则文件，允许系统按 BOM 或文件内容检测编码。
    private func readTextFile(at url: URL) throws -> String {
        var detectedEncoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &detectedEncoding)
    }

    /// 从 Markdown 内容中提取标题和描述
    private func extractTitleAndDescription(from content: String) -> (title: String, description: String) {
        let lines = content.components(separatedBy: .newlines)

        // 提取第一个一级标题作为标题
        var title: String = ""
        var descriptionStartIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("# ") {
                title = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                descriptionStartIndex = index + 1
                break
            }
        }

        // 如果没有找到标题，使用文件名
        if title.isEmpty {
            title = "Untitled Rule"
        }

        // 提取描述（标题后的第一段非空文本）
        var descriptionLines: [String] = []
        for line in lines[descriptionStartIndex...] {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") {
                descriptionLines.append(trimmedLine)
                if descriptionLines.count >= 3 {
                    break
                }
            } else if !descriptionLines.isEmpty {
                break
            }
        }

        let description = descriptionLines.joined(separator: " ").prefix(200).description

        return (title, description.isEmpty ? "No description available" : description)
    }

    /// 从 Markdown 内容中提取描述
    private func extractDescription(from content: String) -> String {
        let (_, description) = extractTitleAndDescription(from: content)
        return description
    }
}

// MARK: - Errors

public enum AgentRulesError: LocalizedError {
    case directoryNotFound(String)
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case invalidFileFormat(String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Rules directory not found: \(path)"
        case .fileNotFound(let path):
            return "Rule file not found: \(path)"
        case .fileAlreadyExists(let path):
            return "Rule file already exists: \(path)"
        case .invalidFileFormat(let message):
            return "Invalid file format: \(message)"
        }
    }
}
