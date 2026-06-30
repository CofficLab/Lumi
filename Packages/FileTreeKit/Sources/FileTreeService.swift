import Foundation

/// 文件树文件系统无状态服务
///
/// 提供目录内容读取、过滤排序、文件操作等纯函数式工具方法。
/// 所有方法均为 `static`，无副作用，线程安全。
public enum FileTreeService {

    // MARK: - 默认忽略的文件名

    /// 默认过滤掉的文件名集合
    public static let defaultHiddenNames: Set<String> = [".DS_Store", ".git"]

    // MARK: - 目录内容

    /// 读取目录内容（过滤并排序后返回）
    ///
    /// 使用 `skipsSubdirectoryDescendants` 避免递归遍历子目录，
    /// 同时利用预取的 `isDirectoryKey` 资源值做排序，减少额外 I/O。
    /// - Parameters:
    ///   - url: 目录 URL
    ///   - hiddenNames: 需要过滤掉的文件名集合，默认为 `.DS_Store` 和 `.git`
    /// - Returns: 过滤并排序后的子项 URL 列表
    /// - Throws: 文件系统读取错误
    public static func loadContents(
        of url: URL,
        hiddenNames: Set<String> = defaultHiddenNames
    ) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsSubdirectoryDescendants
        )
        // 预取目录属性，避免在排序时重复 I/O（O(n) -> O(1) 查询）
        var directoryInfo: [URL: Bool] = [:]
        for item in contents {
            directoryInfo[item] = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
        return filterAndSortContents(contents, directoryInfo: directoryInfo, hiddenNames: hiddenNames)
    }

    /// 过滤并排序目录内容（使用预取的目录信息，避免重复 I/O）
    /// - Parameters:
    ///   - urls: 目录下的 URL 列表
    ///   - directoryInfo: 预取的目录属性映射
    ///   - hiddenNames: 需要过滤掉的文件名集合
    /// - Returns: 过滤并排序后的 URL 列表（文件夹在前）
    public static func filterAndSortContents(
        _ urls: [URL],
        directoryInfo: [URL: Bool],
        hiddenNames: Set<String> = defaultHiddenNames
    ) -> [URL] {
        let filtered = urls.filter { url in
            let name = url.lastPathComponent
            return !hiddenNames.contains(name)
        }

        let sorted = filtered.sorted { a, b in
            let aIsDir = directoryInfo[a] ?? false
            let bIsDir = directoryInfo[b] ?? false
            if aIsDir == bIsDir {
                return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
            return aIsDir
        }

        return sorted
    }

    /// 过滤并排序目录内容（无预取版本，内部会单独查询）
    /// - Parameters:
    ///   - urls: 目录下的 URL 列表
    ///   - hiddenNames: 需要过滤掉的文件名集合
    /// - Returns: 过滤并排序后的 URL 列表（文件夹在前）
    public static func filterAndSortContents(
        _ urls: [URL],
        hiddenNames: Set<String> = defaultHiddenNames
    ) -> [URL] {
        // 内部预取一次，避免排序时重复 I/O
        var directoryInfo: [URL: Bool] = [:]
        for item in urls {
            directoryInfo[item] = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
        return filterAndSortContents(urls, directoryInfo: directoryInfo, hiddenNames: hiddenNames)
    }

    // MARK: - 文件信息查询

    /// 判断 URL 是否为目录
    /// - Parameter url: 文件或目录 URL
    /// - Returns: 是否为目录
    public static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    /// 获取文件图标 SF Symbol 名称（仅根据扩展名）
    /// - Parameter fileExtension: 文件扩展名
    /// - Returns: SF Symbol 名称
    public static func iconSFSymbol(forFileExtension fileExtension: String) -> String {
        iconMap[fileExtension.lowercased()] ?? "doc"
    }

    /// 获取文件图标 SF Symbol 名称（根据 URL，区分目录和文件）
    /// - Parameter url: 文件 URL
    /// - Returns: SF Symbol 名称
    public static func iconSFSymbol(for url: URL) -> String {
        let isDir = isDirectory(url)
        if isDir { return "folder.fill" }
        return iconSFSymbol(forFileExtension: url.pathExtension)
    }

    /// 获取文件显示名称
    /// - Parameter url: 文件 URL
    /// - Returns: 显示名称
    public static func displayName(for url: URL) -> String {
        url.lastPathComponent
    }

    /// 获取文件修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 修改日期
    public static func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// 格式化文件修改日期为相对时间字符串
    /// - Parameter date: 日期
    /// - Returns: 格式化后的字符串
    public static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - 文件操作

    /// 在指定目录下创建新文件
    /// - Parameters:
    ///   - parentURL: 父目录 URL
    ///   - name: 新文件名
    /// - Returns: 创建成功返回新文件 URL，失败返回 nil
    @discardableResult
    public static func createFile(in parentURL: URL, name: String) -> URL? {
        guard isValidItemName(name) else { return nil }
        let fileURL = parentURL.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let success = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        return success ? fileURL : nil
    }

    /// 在指定目录下创建新文件夹
    /// - Parameters:
    ///   - parentURL: 父目录 URL
    ///   - name: 新文件夹名
    /// - Returns: 创建成功返回新文件夹 URL，失败返回 nil
    @discardableResult
    public static func createFolder(in parentURL: URL, name: String) -> URL? {
        guard isValidItemName(name) else { return nil }
        let folderURL = parentURL.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            return folderURL
        } catch {
            return nil
        }
    }

    /// 重命名文件或文件夹
    /// - Parameters:
    ///   - url: 原始 URL
    ///   - newName: 新名称
    /// - Returns: 重命名成功返回新 URL，失败返回 nil
    @discardableResult
    public static func renameItem(at url: URL, newName: String) -> URL? {
        guard isValidItemName(newName) else { return nil }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            return newURL
        } catch {
            return nil
        }
    }

    /// 将文件或文件夹移入废纸篓
    /// - Parameter url: 要删除的 URL
    /// - Returns: 是否成功
    @discardableResult
    public static func trashItem(at url: URL) -> Bool {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }

    /// Validates a single filesystem item name entered from file-tree prompts.
    private static func isValidItemName(_ name: String) -> Bool {
        guard !name.isEmpty, name != ".", name != ".." else { return false }
        return name.rangeOfCharacter(from: CharacterSet(charactersIn: "/\0")) == nil
    }

    // MARK: - Private

    /// 常见文件扩展名到 SF Symbol 的映射
    private static let iconMap: [String: String] = [
        // Swift / Apple
        "swift": "swift",
        "xcodeproj": "hammer",
        "xcworkspace": "hammer",
        "xcassets": "paintpalette",
        "plist": "gearshape",
        "entitlements": "lock.shield",
        "xctestplan": "checkmark.circle",

        // Web
        "html": "globe",
        "htm": "globe",
        "css": "paintbrush",
        "js": "curlybraces",
        "ts": "curlybraces",
        "tsx": "curlybraces",
        "jsx": "curlybraces",
        "vue": "curlybraces",
        "svelte": "curlybraces",

        // Data / Config
        "json": "brace",
        "xml": "doc.text",
        "yaml": "doc.text",
        "yml": "doc.text",
        "toml": "doc.text",
        "ini": "doc.text",
        "conf": "doc.text",
        "env": "gearshape",

        // Markup / Docs
        "md": "doc.richtext",
        "mdx": "doc.richtext",
        "txt": "doc.plaintext",
        "rtf": "doc.richtext",

        // Shell / Scripts
        "sh": "terminal",
        "bash": "terminal",
        "zsh": "terminal",
        "fish": "terminal",
        "py": "doc.text.below.ecg",
        "rb": "diamond",
        "go": "arrow.right",
        "rs": "gearshape",

        // C / C++ / Obj-C
        "c": "text.append",
        "h": "text.append",
        "m": "text.append",
        "mm": "text.append",
        "cpp": "text.append",
        "hpp": "text.append",
        "cc": "text.append",

        // Java / Kotlin
        "java": "cup.and.saucer",
        "kt": "cup.and.saucer",
        "kts": "cup.and.saucer",

        // Images
        "png": "photo",
        "jpg": "photo",
        "jpeg": "photo",
        "gif": "photo",
        "svg": "photo",
        "ico": "photo",
        "webp": "photo",
        "pdf": "doc.richtext",

        // Database
        "sqlite": "cylinder",
        "db": "cylinder",
        "sql": "cylinder",

        // Archive
        "zip": "doc.zipper",
        "gz": "doc.zipper",
        "tar": "doc.zipper",
        "rar": "doc.zipper",
        "7z": "doc.zipper",

        // Lock files
        "lock": "lock",

        // Git
        "gitignore": "arrow.triangle.branch",
        "gitattributes": "arrow.triangle.branch",
        "gitmodules": "arrow.triangle.branch",

        // Docker
        "dockerfile": "shippingbox",

        // Misc
        "log": "list.bullet.rectangle",
        "csv": "tablecells",
        "tsv": "tablecells",
    ]
}
