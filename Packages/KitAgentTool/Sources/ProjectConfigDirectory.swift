import Foundation

/// 项目级配置目录约定。
///
/// Lumi 的项目级配置统一放在项目的 `.lumi/` 目录下（原型、图标设计、
/// App Store 素材等插件均已使用该约定）。
///
/// **写入一律落在 `.lumi/`**；**读取同时兼容历史目录 `.agent/`**，
/// 让旧项目在升级后无需任何改动即可继续使用：
///
/// - 读取：`.lumi/<component>` 全量读取 + `.agent/<component>` 增量补充，
///   同名条目以 `.lumi/` 为准。
/// - 写入：只写 `.lumi/<component>`，绝不改动 `.agent/` 下的历史内容。
public enum ProjectConfigDirectory {

    // MARK: - 常量/静态属性

    /// 当前版本的项目配置目录名（写入目标）。
    public static let current = ".lumi"

    /// 历史版本的项目配置目录名（仅用于兼容读取）。
    public static let legacy = ".agent"

    // MARK: - 公开方法

    /// 写入目标目录 URL。
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录绝对路径。
    ///   - component: 配置子目录名（如 `rules` / `skills`）。
    public static func writeURL(projectPath: String, component: String) -> URL {
        let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser
            : URL(fileURLWithPath: trimmed)
        return base
            .appendingPathComponent(current, isDirectory: true)
            .appendingPathComponent(component, isDirectory: true)
    }

    /// 读取候选目录 URL 列表，按优先级排列。
    ///
    /// 第一项是写入目标 `.lumi/<component>`，其后是历史目录
    /// `.agent/<component>`。调用方应按此顺序遍历，先命中者优先。
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录绝对路径。
    ///   - component: 配置子目录名（如 `rules` / `skills`）。
    public static func readURLs(projectPath: String, component: String) -> [URL] {
        let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser
            : URL(fileURLWithPath: trimmed)
        return [
            base
                .appendingPathComponent(current, isDirectory: true)
                .appendingPathComponent(component, isDirectory: true),
            base
                .appendingPathComponent(legacy, isDirectory: true)
                .appendingPathComponent(component, isDirectory: true),
        ]
    }

    /// 定位某个条目实际所在的路径。
    ///
    /// 依次在 `readURLs` 给出的候选目录中查找，返回第一个已存在的条目路径；
    /// 都不存在时返回 `nil`。
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录绝对路径。
    ///   - component: 配置子目录名（如 `rules` / `skills`）。
    ///   - name: 条目名（文件名或子目录名）。
    /// - Returns: 条目所在路径的 URL；不存在时为 `nil`。
    public static func locate(
        projectPath: String,
        component: String,
        name: String
    ) -> URL? {
        readURLs(projectPath: projectPath, component: component)
            .map { $0.appendingPathComponent(name) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
