import Foundation

/// 从文件系统自动扫描源文件并构建 `XcodeProjectSpec`。
///
/// 使用方式：
/// ```swift
/// let resolver = XcodeProjectSpecResolver()
/// let spec = try resolver.resolve(
///     name: "MyApp",
///     projectRoot: "/path/to/project"
/// )
/// ```
public final class XcodeProjectSpecResolver: Sendable {

    /// 解析选项。
    public struct Options: Sendable {
        /// 需要排除的目录名（默认排除常见的非源码目录）。
        public let excludedDirectoryNames: Set<String>

        /// 需要扫描的源文件扩展名。
        public let sourceExtensions: Set<String>

        /// 需要扫描的资源文件扩展名。
        public let resourceExtensions: Set<String>

        public init(
            excludedDirectoryNames: Set<String> = [
                ".build", ".git", ".swiftpm", ".spm",
                "DerivedData", "build", "Build",
                ".DS_Store", "node_modules",
            ],
            sourceExtensions: Set<String> = ["swift"],
            resourceExtensions: Set<String> = [
                "xcassets", "strings", "xib", "storyboard",
                "plist", "json", "png", "jpg", "pdf",
                "lproj", "stringsdict",
            ]
        ) {
            self.excludedDirectoryNames = excludedDirectoryNames
            self.sourceExtensions = sourceExtensions
            self.resourceExtensions = resourceExtensions
        }
    }

    private let options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    // MARK: - Public API

    /// 扫描项目目录，自动发现源文件和资源文件。
    ///
    /// - Parameters:
    ///   - projectRoot: 项目根目录的绝对路径。
    /// - Returns: 扫描结果，包含发现的所有源文件和资源文件路径。
    public func scan(projectRoot: String) throws -> ScanResult {
        let rootURL = URL(fileURLWithPath: projectRoot)
        let fm = FileManager.default

        var sources: [String] = []
        var resources: [String] = []

        // 获取项目根目录下的直接子目录和文件
        guard let contents = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw XcodeProjectGenError.scanFailed("Cannot read directory: \(projectRoot)")
        }

        for itemURL in contents {
            let name = itemURL.lastPathComponent

            // 跳过排除目录
            if options.excludedDirectoryNames.contains(name) { continue }
            // 跳过 .xcodeproj 和 .xcworkspace
            if name.hasSuffix(".xcodeproj") || name.hasSuffix(".xcworkspace") { continue }
            // 跳过 Package.swift、README 等文件
            if name == "Package.swift" || name == "Package.resolved" { continue }

            let relativePath = name

            var isDir: ObjCBool = false
            fm.fileExists(atPath: itemURL.path, isDirectory: &isDir)

            if isDir.boolValue {
                // 判断是源码目录还是资源目录
                if isResourceDirectory(name) {
                    resources.append(relativePath)
                } else if containsSourceFiles(at: itemURL.path) {
                    sources.append(relativePath)
                }
            } else {
                // 单文件
                let ext = itemURL.pathExtension
                if options.sourceExtensions.contains(ext) {
                    sources.append(relativePath)
                } else if options.resourceExtensions.contains(ext) {
                    resources.append(relativePath)
                }
            }
        }

        return ScanResult(
            sources: sources.sorted(),
            resources: resources.sorted()
        )
    }

    /// 扫描指定目录，查找所有 Swift 源文件。
    ///
    /// - Parameters:
    ///   - directory: 目录绝对路径。
    /// - Returns: 相对于项目根目录的文件路径列表。
    public func scanSources(in directory: String, relativeTo projectRoot: String) throws -> [String] {
        let fm = FileManager.default
        var files: [String] = []

        guard let enumerator = fm.enumerator(atPath: directory) else {
            throw XcodeProjectGenError.scanFailed("Cannot enumerate directory: \(directory)")
        }

        for case let item as String in enumerator {
            // 跳过排除目录
            let components = item.components(separatedBy: "/")
            if components.contains(where: { options.excludedDirectoryNames.contains($0) }) {
                enumerator.skipDescendants()
                continue
            }

            if options.sourceExtensions.contains(where: { item.hasSuffix(".\($0)") }) {
                let fullPath = (directory as NSString).appendingPathComponent(item)
                let relative = XcodeProjectPathUtility.relativePath(
                    for: fullPath,
                    rootPath: projectRoot,
                    fallbackName: (fullPath as NSString).lastPathComponent
                )
                files.append(relative)
            }
        }

        return files.sorted()
    }

    /// 扫描指定目录，查找所有资源文件。
    ///
    /// - Parameters:
    ///   - directory: 目录绝对路径。
    /// - Returns: 相对于项目根目录的文件路径列表。
    public func scanResources(in directory: String, relativeTo projectRoot: String) throws -> [String] {
        let fm = FileManager.default
        var files: [String] = []

        guard let enumerator = fm.enumerator(atPath: directory) else {
            throw XcodeProjectGenError.scanFailed("Cannot enumerate directory: \(directory)")
        }

        for case let item as String in enumerator {
            // 跳过排除目录
            let components = item.components(separatedBy: "/")
            if components.contains(where: { options.excludedDirectoryNames.contains($0) }) {
                enumerator.skipDescendants()
                continue
            }

            // 跳过 Swift 源文件
            if item.hasSuffix(".swift") { continue }

            let ext = (item as NSString).pathExtension
            if !ext.isEmpty {
                // 检查是否是资源扩展名，或者是否在 .lproj 目录中
                if options.resourceExtensions.contains(ext) || item.contains(".lproj/") {
                    let fullPath = (directory as NSString).appendingPathComponent(item)
                    let relative = XcodeProjectPathUtility.relativePath(
                        for: fullPath,
                        rootPath: projectRoot,
                        fallbackName: (fullPath as NSString).lastPathComponent
                    )
                    files.append(relative)
                }
            }

            // xcassets 是资源目录
            if item.hasSuffix(".xcassets") {
                let fullPath = (directory as NSString).appendingPathComponent(item)
                let relative = XcodeProjectPathUtility.relativePath(
                    for: fullPath,
                    rootPath: projectRoot,
                    fallbackName: (fullPath as NSString).lastPathComponent
                )
                files.append(relative)
                enumerator.skipDescendants()
            }
        }

        return files.sorted()
    }

    // MARK: - Private Helpers

    /// 判断目录名是否看起来像资源目录。
    private func isResourceDirectory(_ name: String) -> Bool {
        let resourceDirSuffixes = [".xcassets", ".bundle", ".lproj"]
        let resourceDirNames = ["Resources", "Assets", "Fonts", "Images", "Colors", "Strings"]

        if resourceDirSuffixes.contains(where: { name.hasSuffix($0) }) {
            return true
        }
        if resourceDirNames.contains(name) {
            return true
        }
        return false
    }

    /// 递归检查目录是否包含源文件。
    private func containsSourceFiles(at path: String) -> Bool {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return false }

        for case let item as String in enumerator {
            let components = item.components(separatedBy: "/")
            if components.contains(where: { options.excludedDirectoryNames.contains($0) }) {
                enumerator.skipDescendants()
                continue
            }
            if options.sourceExtensions.contains(where: { item.hasSuffix(".\($0)") }) {
                return true
            }
        }
        return false
    }
}

// MARK: - ScanResult

/// 文件系统扫描结果。
public struct ScanResult: Sendable {
    /// 发现的源文件路径列表（相对于项目根目录）。
    public let sources: [String]

    /// 发现的资源文件路径列表（相对于项目根目录）。
    public let resources: [String]
}
