import Foundation

public enum RAGFileScanner {
    /// 需要跳过的目录列表（精确匹配目录名）。
    ///
    /// `build` 已包含其中，因此 `build/SourcePackages` 会被一并跳过；独立的顶层
    /// `SourcePackages/`（如某些项目直接放在根目录）也在此显式跳过。
    public static let skipDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData", "Pods", "Carthage", "node_modules", "dist", "build",
        "temp", "SourcePackages",
    ]

    /// 需要按前缀跳过的目录名。
    ///
    /// Xcode 会为每个 scheme 生成形如 `DerivedData-Lumi-Multilang`、
    /// `DerivedData-Lumi-PluginDescriptionLocalization` 的派生目录，无法用精确名匹配，
    /// 这里按前缀 `DerivedData` 跳过所有变体。
    public static let skipDirectoryPrefixes: Set<String> = ["DerivedData"]

    /// 允许索引的文件扩展名
    public static let allowedExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp",
        "js", "ts", "tsx", "jsx", "json", "yml", "yaml", "toml",
        "md", "txt", "rst", "py", "rb", "go", "rs", "java", "kt",
        "sql", "html", "css", "scss", "xml", "sh", "zsh",
    ]

    /// 默认最大文件大小限制（1.5MB）
    public static let defaultMaxFileSizeBytes = 1_500_000

    /// `discoverFiles` 的短期内存缓存（TTL 5 分钟）。
    ///
    /// grep 路径不枚举文件；仅当 grep 不可用、回退到逐文件搜索时才会调用 `discoverFiles`。
    /// 同一项目短时间内重复回退搜索时，缓存可避免每次都重新遍历整棵目录树。
    /// 缓存键为 projectPath，按时间戳过期，线程安全。
    private static let cacheTTL: TimeInterval = 300
    private static let cache = DiscoverFilesCache()

    /// 带缓存的 `discoverFiles`：命中且未过期时直接返回缓存结果，否则重新扫描并写入缓存。
    public static func discoverFilesCached(in projectPath: String, maxFileSizeBytes: Int = defaultMaxFileSizeBytes) -> [String] {
        if let cached = cache.get(projectPath: projectPath, now: Date()) {
            return cached
        }
        let files = discoverFiles(in: projectPath, maxFileSizeBytes: maxFileSizeBytes)
        cache.set(projectPath: projectPath, files: files, expiresAt: Date(timeIntervalSinceNow: cacheTTL))
        return files
    }

    /// 扫描项目目录下的所有文件
    public static func discoverFiles(in projectPath: String, maxFileSizeBytes: Int = defaultMaxFileSizeBytes) -> [String] {
        let rootURL = URL(fileURLWithPath: projectPath)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []

        for case let url as URL in enumerator {
            let path = url.path
            if shouldSkipPath(path) {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }

            let ext = url.pathExtension.lowercased()
            guard Self.allowedExtensions.contains(ext) else { continue }

            if let size = values.fileSize, size > maxFileSizeBytes { continue }

            files.append(path)
        }

        return files
    }

    /// 判断路径是否应该跳过
    public static func shouldSkipPath(_ path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        for component in components {
            // 精确匹配作用于所有路径段（含目录条目本身），保留 discoverFiles 的
            // skipDescendants() 剪枝能力——遇到 build/.git 等目录时整棵子树直接跳过。
            if Self.skipDirectories.contains(component) {
                return true
            }
            // 前缀匹配只作用于「看起来像目录」的段：目录名通常不含点。
            // 这样既能覆盖 DerivedData-Lumi-* 变体目录，又不会误杀形如
            // DerivedDataHelper.swift 的源文件（文件名带扩展名/点）。
            if !component.contains("."),
               Self.skipDirectoryPrefixes.contains(where: { component.hasPrefix($0) }) {
                return true
            }
        }
        return false
    }

    /// 传给 `grep --exclude-dir` 的排除模式列表。
    ///
    /// 精确名直接透传；前缀模式（如 `DerivedData`）以 `DerivedData*` 的 glob 形式给出，
    /// 让 grep 一次性排除所有变体，无需在命令行展开每个具体目录名。
    public static var grepExcludeDirPatterns: [String] {
        var patterns = Array(skipDirectories)
        patterns.append(contentsOf: skipDirectoryPrefixes.map { "\($0)*" })
        return patterns
    }
}

/// `discoverFiles` 结果的线程安全 TTL 缓存。
///
/// 单独抽出为 `@unchecked Sendable` 类，用内部锁保护可变状态，满足严格并发检查下
/// 「全局共享可变状态必须并发安全」的要求（裸 `static var` 会被诊断拒绝）。
private final class DiscoverFilesCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: (files: [String], expiresAt: Date)] = [:]

    func get(projectPath: String, now: Date) -> [String]? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[projectPath], entry.expiresAt > now else { return nil }
        return entry.files
    }

    func set(projectPath: String, files: [String], expiresAt: Date) {
        lock.lock(); defer { lock.unlock() }
        entries[projectPath] = (files, expiresAt)
    }
}
