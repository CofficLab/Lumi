import Foundation

/// .gitignore 文件读写与解析服务。
///
/// `.gitignore` 是纯文本，git 本身不提供结构化查询；
/// 我们直接做字符串读写 + 注释剥离，避免引入额外依赖。
public enum GitIgnoreService {

    /// 项目根目录下 .gitignore 的相对路径。
    public static let relativePath = ".gitignore"

    public static func fullPath(forProjectAt projectPath: String) -> String {
        (projectPath as NSString).appendingPathComponent(relativePath)
    }

    public static func exists(forProjectAt projectPath: String) -> Bool {
        FileManager.default.fileExists(atPath: fullPath(forProjectAt: projectPath))
    }

    /// 读取当前 .gitignore 内容；不存在时返回 nil。
    public static func read(forProjectAt projectPath: String) -> String? {
        let path = fullPath(forProjectAt: projectPath)
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// 写入 .gitignore，失败抛出错误。
    public static func write(_ content: String, forProjectAt projectPath: String) throws {
        let path = fullPath(forProjectAt: projectPath)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - 解析

    /// 一行规则。
    public struct Rule: Hashable, Identifiable {
        public enum Kind: Hashable {
            case pattern      // 有效规则
            case negation     // 以 ! 开头
            case directory    // 以 / 结尾
            case comment      // 以 # 开头
            case blank        // 空行
        }
        public let id = UUID()
        public let raw: String
        public let kind: Kind
        public let text: String   // 去掉前缀后的纯规则文本
    }

    /// 解析 .gitignore 内容为规则行。
    public static func parse(_ content: String) -> [Rule] {
        content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Rule in
                let raw = String(line)
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    return Rule(raw: raw, kind: .blank, text: "")
                }
                if trimmed.hasPrefix("#") {
                    return Rule(raw: raw, kind: .comment, text: trimmed)
                }
                if trimmed.hasPrefix("!") {
                    return Rule(raw: raw, kind: .negation, text: String(trimmed.dropFirst()))
                }
                if trimmed.hasSuffix("/") {
                    return Rule(raw: raw, kind: .directory, text: String(trimmed.dropLast()))
                }
                return Rule(raw: raw, kind: .pattern, text: trimmed)
            }
    }

    /// 重新组装为可写回的内容。
    public static func serialize(_ rules: [Rule]) -> String {
        rules.map(\.raw).joined(separator: "\n")
    }

    // MARK: - 模板

    /// 常用模板：用于「插入模板」按钮。
    public static func template(_ name: String) -> String? {
        switch name.lowercased() {
        case "node":     return nodeTemplate
        case "macos":    return macOSTemplate
        case "swift":    return swiftTemplate
        case "python":   return pythonTemplate
        case "java":     return javaTemplate
        case "vscode":   return vscodeTemplate
        default:         return nil
        }
    }

    public static let availableTemplates: [String] = [
        "Node", "macOS", "Swift", "Python", "Java", "VSCode",
    ]

    public static let nodeTemplate = """
    # Node
    node_modules/
    npm-debug.log*
    yarn-debug.log*
    yarn-error.log*
    .npm/
    .yarn/
    """

    public static let macOSTemplate = """
    # macOS
    .DS_Store
    .AppleDouble
    .LSOverride
    Icon?
    """

    public static let swiftTemplate = """
    # Swift / Xcode
    .build/
    DerivedData/
    *.xcodeproj/xcuserdata/
    *.xcworkspace/xcuserdata/
    *.xcuserstate
    Package.resolved
    .swiftpm/
    """

    public static let pythonTemplate = """
    # Python
    __pycache__/
    *.py[cod]
    *.egg-info/
    .venv/
    venv/
    .pytest_cache/
    """

    public static let javaTemplate = """
    # Java / JVM
    target/
    *.class
    *.jar
    .gradle/
    .idea/
    """

    public static let vscodeTemplate = """
    # VSCode
    .vscode/
    !.vscode/settings.json
    !.vscode/extensions.json
    """
}
