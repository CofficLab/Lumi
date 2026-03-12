import Foundation

/// 项目命令模型 - 表示从 .agent/commands 目录加载的命令
struct ProjectCommand: Identifiable, Equatable {
    let id = UUID()

    /// 命令名称（不含 .md 扩展名）
    let name: String

    /// 命令文件路径
    let filePath: String

    /// 命令描述（来自 frontmatter 或文件第一行）
    let description: String

    /// 命令完整内容（Markdown）
    let content: String

    /// 允许使用的工具（来自 frontmatter）
    let allowedTools: [String]?

    /// 指定使用的模型（来自 frontmatter）
    let model: String?

    /// 参数提示（来自 frontmatter）
    let argumentHint: String?

    /// 是否禁用模型调用（来自 frontmatter）
    let disableModelInvocation: Bool

    /// 命令来源
    enum Source: Equatable {
        case project(String) // 项目路径
        case user // 用户全局命令 ~/.agent/commands
        case plugin(String) // 插件名称
    }

    let source: Source

    /// 显示名称（用于 UI）
    var displayName: String {
        switch source {
        case .project:
            return "/\(name)"
        case .user:
            return "/\(name) (user)"
        case let .plugin(pluginName):
            return "/\(name) (\(pluginName))"
        }
    }

    /// 是否支持参数
    var supportsArguments: Bool {
        content.contains("$ARGUMENTS") ||
            content.contains("$1") ||
            content.contains("$2") ||
            argumentHint != nil
    }

    /// 创建命令的 Slash 格式
    var slashCommand: String {
        "/\(name)"
    }

    init(
        name: String,
        filePath: String,
        description: String,
        content: String,
        allowedTools: [String]? = nil,
        model: String? = nil,
        argumentHint: String? = nil,
        disableModelInvocation: Bool = false,
        source: Source
    ) {
        self.name = name
        self.filePath = filePath
        self.description = description
        self.content = content
        self.allowedTools = allowedTools
        self.model = model
        self.argumentHint = argumentHint
        self.disableModelInvocation = disableModelInvocation
        self.source = source
    }
}

// MARK: - YAML Frontmatter 解析

struct CommandFrontmatter {
    var description: String?
    var allowedTools: [String]?
    var model: String?
    var argumentHint: String?
    var disableModelInvocation: Bool = false

    static func parse(from content: String) -> (frontmatter: CommandFrontmatter?, body: String) {
        guard content.hasPrefix("---") else {
            return (nil, content)
        }

        // 查找 frontmatter 结束标记
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var frontmatterEndIndex = -1

        for (index, line) in lines.enumerated() {
            if index > 0 && line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = index
                break
            }
        }

        guard frontmatterEndIndex > 0 else {
            return (nil, content)
        }

        // 提取 frontmatter 内容
        let frontmatterLines = Array(lines[1 ..< frontmatterEndIndex])
        let frontmatterString = frontmatterLines.joined(separator: "\n")

        // 提取 body
        let bodyStartIndex = frontmatterEndIndex + 1
        let body = bodyStartIndex < lines.count
            ? Array(lines[bodyStartIndex...]).joined(separator: "\n")
            : ""

        // 解析 YAML
        var frontmatter = CommandFrontmatter()

        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains(":") else { continue }

            let parts = trimmed.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }

            let key = parts[0]
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            // 移除引号
            let cleanValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            switch key {
            case "description":
                frontmatter.description = cleanValue
            case "allowed-tools":
                frontmatter.allowedTools = parseAllowedTools(cleanValue)
            case "model":
                frontmatter.model = cleanValue
            case "argument-hint":
                frontmatter.argumentHint = cleanValue
            case "disable-model-invocation":
                frontmatter.disableModelInvocation = cleanValue.lowercased() == "true"
            default:
                break
            }
        }

        return (frontmatter, body)
    }

    private static func parseAllowedTools(_ value: String) -> [String]? {
        // 支持数组格式：["Read", "Write"] 或字符串格式：Read, Write
        if value.hasPrefix("[") && value.hasSuffix("]") {
            // 数组格式
            let inner = value.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
            if inner.isEmpty { return [] }

            return inner.split(separator: ",").map {
                String($0).trimmingCharacters(in: CharacterSet(charactersIn: " \n\r\t\"'"))
            }
        } else {
            // 字符串格式
            return value.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
        }
    }
}
