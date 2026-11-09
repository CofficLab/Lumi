import Foundation

/// CLI 安装目标的候选目录。
///
/// 用户的终端 `PATH` 里通常已经有若干可写目录（Homebrew 的 `/opt/homebrew/bin`、
/// `~/.local/bin` 等）。把脚本装进**已经在 PATH 中**的目录，安装完立刻就能用
/// `lumi`，不必再让用户去改 shell 配置。
public struct CLIInstallTarget: Equatable, Sendable {
    /// 目标目录的绝对路径。
    public let directory: URL
    /// 该目录是否已在用户的终端 `PATH` 中。
    public let isOnPath: Bool
    /// 该目录是否可写。
    public let isWritable: Bool

    public init(directory: URL, isOnPath: Bool, isWritable: Bool) {
        self.directory = directory
        self.isOnPath = isOnPath
        self.isWritable = isWritable
    }

    /// 脚本文件的完整路径。
    public func scriptURL(for commandName: String) -> URL {
        directory.appendingPathComponent(commandName)
    }
}

/// 负责挑选 CLI 脚本的安装目录。
///
/// 选择顺序：
/// 1. 用户终端 `PATH` 中**已经存在且可写**的目录（装完立即可用）；
/// 2. 常见偏好目录（Homebrew 等，可能尚未在 `PATH` 中）；
/// 3. 兜底 `~/.local/bin`（Unix 惯例目录，无需管理员权限）。
public enum CLIInstallTargetResolver {
    /// 常见偏好目录，按优先级排序。
    ///
    /// 顺序刻意把 Homebrew 目录放在前面：绝大多数 macOS 开发者装了
    /// Homebrew，且 `/opt/homebrew/bin` 默认在 `PATH` 中。
    public static let preferredDirectories: [String] = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin",
        "/usr/bin",
    ]

    /// 用户级目录名（`~/.local/bin`）。
    public static let userDirectoryName = ".local/bin"

    /// 计算候选安装目录列表。
    ///
    /// - Parameters:
    ///   - pathEntries: 用户终端的 `PATH` 条目（见 `CLIPathResolver`）。
    ///   - environment: 环境变量字典（用于读取 `HOME`）。
    ///   - fileManager: 文件管理器（用于检查目录存在性与可写性）。
    /// - Returns: 按优先级排序的候选目录；`isOnPath` 标记该目录是否已在 `PATH` 中。
    public static func candidates(
        pathEntries: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [CLIInstallTarget] {
        let pathSet = Set(
            pathEntries.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        )

        var result: [CLIInstallTarget] = []
        var seenPaths = Set<String>()

        // 1) PATH 中已存在且可写的目录。
        for entry in pathEntries {
            let url = URL(fileURLWithPath: entry)
            let standardized = url.standardizedFileURL
            let path = standardized.path
            guard !seenPaths.contains(path) else { continue }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            guard fileManager.isWritableFile(atPath: path) else { continue }

            // 只有真正收下的目录才记为“见过”。缺失的 PATH 项若提前占位，
            // 会让后面的 ~/.local/bin 兜底误以为已经处理过而跳过（issue #945）。
            seenPaths.insert(path)
            result.append(
                CLIInstallTarget(
                    directory: standardized,
                    isOnPath: true,
                    isWritable: true
                )
            )
        }

        // 2) 常见偏好目录（可能尚未在 PATH 中，但通常在）。
        for candidate in preferredDirectories {
            let url = URL(fileURLWithPath: candidate)
            let standardized = url.standardizedFileURL
            let path = standardized.path
            guard !seenPaths.contains(path) else { continue }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            guard fileManager.isWritableFile(atPath: path) else { continue }

            seenPaths.insert(path)
            result.append(
                CLIInstallTarget(
                    directory: standardized,
                    isOnPath: pathSet.contains(path),
                    isWritable: true
                )
            )
        }

        // 3) 用户级目录：始终作为兜底（不存在时安装时再创建）。
        if let home = environment["HOME"] {
            let userDirectory = URL(fileURLWithPath: home)
                .appendingPathComponent(userDirectoryName, isDirectory: true)
                .standardizedFileURL
            let path = userDirectory.path
            if !seenPaths.contains(path) {
                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
                result.append(
                    CLIInstallTarget(
                        directory: userDirectory,
                        isOnPath: pathSet.contains(path),
                        isWritable: exists
                            ? fileManager.isWritableFile(atPath: path)
                            : true
                    )
                )
            }
        }

        return result
    }

    /// 选出最佳安装目标。
    ///
    /// 优先返回**已在 PATH 中且可写**的目录；否则返回第一个可写目录；
    /// 都不可写时返回 `nil`（此时应提示用户手动安装）。
    public static func bestTarget(
        pathEntries: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> CLIInstallTarget? {
        let all = candidates(
            pathEntries: pathEntries,
            environment: environment,
            fileManager: fileManager
        )
        if let onPath = all.first(where: { $0.isOnPath && $0.isWritable }) {
            return onPath
        }
        return all.first(where: { $0.isWritable })
    }
}
