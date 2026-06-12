import Foundation

/// Vue 项目扫描器
///
/// 扫描项目中的 `.vue` 组件文件，构建组件名 → 文件路径的映射表，
/// 供组件自动导入和补全功能使用。
struct VueProjectScanner: Sendable {
    nonisolated static let emoji = "🔍"

    /// 需要跳过的目录
    private static let skipDirectories: Set<String> = [
        "node_modules", ".git", "dist", "build",
        ".nuxt", ".next", ".output",
        "coverage", ".cache",
    ]

    /// 组件扫描结果
    struct ComponentEntry: Sendable {
        /// PascalCase 组件名（如 `MyButton`）
        let name: String
        /// 文件绝对路径
        let path: String
        /// 相对项目根目录的路径
        let relativePath: String
    }

    // MARK: - 公开方法

    /// 扫描项目目录，返回所有找到的 `.vue` 组件
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - maxResults: 最大扫描数量（防止超大项目卡死）
    /// - Returns: 组件条目列表
    static func scan(projectPath: String, maxResults: Int = 500) -> [ComponentEntry] {
        var results: [ComponentEntry] = []
        let fm = FileManager.default
        let baseURL = URL(fileURLWithPath: projectPath)

        guard let enumerator = fm.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if results.count >= maxResults { break }

            // 跳过目标目录
            if skipDirectories.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            // 只处理 .vue 文件
            guard fileURL.pathExtension.lowercased() == "vue" else { continue }

            let absolutePath = fileURL.path
            let relativePath = relativePath(for: fileURL, rootPath: projectPath)

            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let componentName = fileNameToComponentName(fileName)

            results.append(ComponentEntry(
                name: componentName,
                path: absolutePath,
                relativePath: String(relativePath)
            ))
        }

        return results.sorted { $0.name < $1.name }
    }

    /// 构建组件名 → 文件路径的映射表
    static func componentMap(projectPath: String, maxResults: Int = 500) -> [String: String] {
        let entries = scan(projectPath: projectPath, maxResults: maxResults)
        var map: [String: String] = [:]

        for entry in entries {
            // 注册 PascalCase 名
            map[entry.name] = entry.relativePath

            // 也注册 kebab-case 名
            let kebabName = pascalToKebab(entry.name)
            if map[kebabName] == nil {
                map[kebabName] = entry.relativePath
            }
        }

        return map
    }

    /// 生成组件的相对导入路径（带或不带扩展名）
    static func importPath(for component: ComponentEntry, relativeTo currentFile: URL) -> String {
        let relPath = relativeImportPath(
            from: currentFile.deletingLastPathComponent(),
            to: URL(fileURLWithPath: component.path)
        )

        // 确保以 ./ 或 ../ 开头
        var importPath = relPath.hasPrefix("../") ? relPath : "./" + relPath

        // 移除 .vue 扩展名（现代构建工具可自动解析）
        if importPath.hasSuffix(".vue") {
            importPath = String(importPath.dropLast(4))
        }

        return importPath
    }

    // MARK: - 辅助方法

    /// 将文件名转换为 PascalCase 组件名
    static func fileNameToComponentName(_ name: String) -> String {
        // 处理 kebab-case: my-button -> MyButton
        if name.contains("-") {
            return name.split(separator: "-")
                .map { part in
                    guard let first = part.first else { return "" }
                    return first.uppercased() + part.dropFirst().lowercased()
                }
                .joined()
        }

        // 处理 snake_case: my_button -> MyButton
        if name.contains("_") {
            return name.split(separator: "_")
                .map { part in
                    guard let first = part.first else { return "" }
                    return first.uppercased() + part.dropFirst().lowercased()
                }
                .joined()
        }

        // 已经是 PascalCase 或 camelCase
        if let first = name.first {
            return first.uppercased() + name.dropFirst()
        }

        return name
    }

    /// PascalCase 转 kebab-case
    static func pascalToKebab(_ name: String) -> String {
        var result = ""
        for (i, char) in name.enumerated() {
            if char.isUppercase && i > 0 {
                result += "-"
            }
            result += char.lowercased()
        }
        return result
    }

    static func relativePath(for fileURL: URL, rootPath: String) -> String {
        let filePath = normalizedPath(fileURL.path)
        let root = normalizedPath(rootPath)

        guard !root.isEmpty, filePath != root else {
            return fileURL.lastPathComponent
        }

        let rootPrefix = root == "/" ? "/" : root + "/"
        guard filePath.hasPrefix(rootPrefix) else {
            return fileURL.lastPathComponent
        }

        return String(filePath.dropFirst(rootPrefix.count))
    }

    static func relativeImportPath(from directoryURL: URL, to fileURL: URL) -> String {
        let fromComponents = normalizedPath(directoryURL.path)
            .split(separator: "/")
            .map(String.init)
        let toComponents = normalizedPath(fileURL.path)
            .split(separator: "/")
            .map(String.init)

        var commonCount = 0
        while commonCount < fromComponents.count,
              commonCount < toComponents.count,
              fromComponents[commonCount] == toComponents[commonCount] {
            commonCount += 1
        }

        let parentSegments = Array(repeating: "..", count: fromComponents.count - commonCount)
        let targetSegments = Array(toComponents.dropFirst(commonCount))
        let segments = parentSegments + targetSegments

        return segments.isEmpty ? fileURL.lastPathComponent : segments.joined(separator: "/")
    }

    private static func normalizedPath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        guard standardized.count > 1 else { return standardized }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }
}
