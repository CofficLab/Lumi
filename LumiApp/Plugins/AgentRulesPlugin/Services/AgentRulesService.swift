import Foundation

/// Agent 规则服务
///
/// 负责管理 .agent/rules 目录中的规则文档
actor AgentRulesService {
    static let shared = AgentRulesService()

    /// 当前项目路径（由 RootView 同步）
    private var currentProjectPath: String = ""

    /// 设置当前项目路径
    func setCurrentProjectPath(_ path: String) {
        currentProjectPath = path
    }

    /// 获取当前项目路径
    func getCurrentProjectPath() -> String {
        currentProjectPath
    }

    /// 规则目录路径
    private var rulesDirectoryURL: URL {
        // 优先使用当前项目路径
        if !currentProjectPath.isEmpty {
            let projectURL = URL(fileURLWithPath: currentProjectPath)
            let rulesPath = projectURL.appending(path: ".agent/rules")
            if FileManager.default.fileExists(atPath: rulesPath.path()) {
                return rulesPath
            }
        }

        // 获取项目根目录（回退方案）
        if let cwd = URL(string: FileManager.default.currentDirectoryPath) {
            let rulesPath = cwd.appending(path: ".agent/rules")
            if FileManager.default.fileExists(atPath: rulesPath.path()) {
                return rulesPath
            }
        }

        // 回退到主 bundle 资源路径（用于开发环境）
        if let resourcePath = Bundle.main.resourcePath {
            let rulesPath = URL(fileURLWithPath: resourcePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: ".agent/rules")
            if FileManager.default.fileExists(atPath: rulesPath.path()) {
                return rulesPath
            }
        }

        // 最终回退到主目录下的 .agent/rules
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appending(path: ".agent/rules")
    }

    /// 获取规则文档列表
    func listRules() async throws -> [AgentRuleMetadata] {
        let directoryURL = rulesDirectoryURL

        // 确保目录存在
        guard FileManager.default.fileExists(atPath: directoryURL.path()) else {
            throw AgentRulesError.directoryNotFound(directoryURL.path())
        }

        // 获取目录中的所有 .md 文件
        let files = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ],
            options: [.skipsHiddenFiles]
        )

        var rules: [AgentRuleMetadata] = []

        for file in files where file.pathExtension == "md" {
            let resourceValues = try file.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ])

            let fileSize = resourceValues.fileSize ?? 0
            let modifiedAt = resourceValues.contentModificationDate ?? Date()
            _ = resourceValues.creationDate ?? Date()

            // 读取文件内容以提取标题和描述
            let content = try String(contentsOf: file, encoding: .utf8)
            let (title, description) = extractTitleAndDescription(from: content)

            let filename = file.lastPathComponent
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

        // 按修改时间排序（最新的在前）
        rules.sort { $0.modifiedAt > $1.modifiedAt }

        return rules
    }

    /// 读取规则文档内容
    func readRule(filename: String) async throws -> AgentRule {
        let directoryURL = rulesDirectoryURL
        let fileURL = directoryURL.appending(path: filename)

        // 确保文件存在
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw AgentRulesError.fileNotFound(fileURL.path())
        }

        // 读取文件内容
        let content = try String(contentsOf: fileURL, encoding: .utf8)

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
    func createRule(
        filename: String,
        title: String,
        content: String
    ) async throws -> AgentRule {
        let directoryURL = rulesDirectoryURL

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

enum AgentRulesError: LocalizedError {
    case directoryNotFound(String)
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case invalidFileFormat(String)

    var errorDescription: String? {
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
