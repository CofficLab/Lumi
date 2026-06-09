import Foundation
import EditorService

/// HTML 路径补全
///
/// 为 `src` 和 `href` 属性提供本地文件路径补全。
///
/// 触发条件：
/// - 光标在 `src="..."` 或 `href="..."` 的属性值内
/// - 属性值以 `/` 或 `./` 或 `../` 开头
public enum HTMLPathCompletion {
    /// 需要路径补全的属性列表
    public static let pathAttributes: Set<String> = ["src", "href", "action", "data", "poster", "formaction"]

    /// 检查当前上下文是否需要路径补全
    ///
    /// - Parameters:
    ///   - lineText: 当前行文本
    ///   - character: 光标列号
    /// - Returns: 如果需要路径补全，返回属性名
    public static func isPathContext(lineText: String, character: Int) -> String? {
        let textBeforeCursor = String(lineText.prefix(character))

        for attr in pathAttributes {
            // 匹配 src="、src='、href=" 等
            let patterns = [
                "\(attr)=\"",
                "\(attr)='",
                "\(attr) =\"",
                "\(attr) ='",
            ]

            for pattern in patterns {
                if textBeforeCursor.hasSuffix(pattern) {
                    return attr
                }
            }

            // 匹配 src="./、src="/、src="../ 等
            let pathPatterns = [
                "\(attr)=\"/",
                "\(attr)='/",
                "\(attr)=\"./",
                "\(attr)='./",
                "\(attr)=\"../",
                "\(attr)='../",
            ]

            for pattern in pathPatterns {
                if textBeforeCursor.hasSuffix(pattern) {
                    return attr
                }
            }
        }

        return nil
    }

    /// 为项目目录生成路径补全建议
    ///
    /// - Parameters:
    ///   - prefix: 已输入的路径前缀
    ///   - projectRoot: 项目根目录路径
    ///   - currentFile: 当前文件路径（用于相对路径计算）
    /// - Returns: 路径补全建议数组
    public static func provideSuggestions(
        prefix: String,
        projectRoot: String,
        currentFile: String? = nil
    ) -> [EditorCompletionSuggestion] {
        let fileManager = FileManager.default
        var suggestions: [EditorCompletionSuggestion] = []

        // 确定搜索目录
        let searchDir: String
        var relativePrefix = prefix

        if prefix.hasPrefix("/") {
            // 绝对路径
            searchDir = projectRoot
            relativePrefix = String(prefix.dropFirst())
        } else if prefix.hasPrefix("./") {
            // 相对路径
            if let currentFile = currentFile {
                searchDir = (currentFile as NSString).deletingLastPathComponent
                relativePrefix = String(prefix.dropFirst(2))
            } else {
                searchDir = projectRoot
                relativePrefix = String(prefix.dropFirst(2))
            }
        } else if prefix.hasPrefix("../") {
            // 父目录路径
            if let currentFile = currentFile {
                let parentDir = ((currentFile as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
                searchDir = parentDir
                relativePrefix = String(prefix.dropFirst(3))
            } else {
                searchDir = projectRoot
                relativePrefix = String(prefix.dropFirst(3))
            }
        } else {
            searchDir = projectRoot
            relativePrefix = prefix
        }

        // 列出目录内容
        guard let enumerator = fileManager.enumerator(atPath: searchDir) else { return [] }

        var items: [(name: String, isDirectory: Bool, path: String)] = []

        while let element = enumerator.nextObject() as? String {
            let fullPath = (searchDir as NSString).appendingPathComponent(element)
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                let displayName = relativePrefix.isEmpty ? element : element
                if relativePrefix.isEmpty || displayName.hasPrefix(relativePrefix) {
                    items.append((name: element, isDirectory: isDirectory.boolValue, path: element))
                }
            }
        }

        // 限制结果数量
        for item in items.prefix(50) {
            let insertText = prefix + item.path + (item.isDirectory ? "/" : "")
            let icon = item.isDirectory ? "📁" : "📄"
            suggestions.append(
                EditorCompletionSuggestion(
                    label: "\(icon) \(item.name)",
                    insertText: insertText,
                    detail: item.isDirectory ? "Directory" : "File",
                    priority: 900
                )
            )
        }

        return suggestions
    }
}
