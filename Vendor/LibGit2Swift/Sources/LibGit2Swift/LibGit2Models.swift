import Foundation

extension LibGit2 {
    /// Stable facade names for model types used by clients that also import a
    /// package or enum named `LibGit2Swift`.
    public typealias Commit = GitCommit
    public typealias DiffFile = GitDiffFile
    public typealias RepositoryStatusEntry = GitRepositoryStatusEntry
}

/// Git 分支模型
public struct GitBranch: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let isCurrent: Bool
    public let upstream: String?
    public let latestCommitHash: String
    public let latestCommitMessage: String

    public init(id: String, name: String, isCurrent: Bool, upstream: String?, latestCommitHash: String, latestCommitMessage: String) {
        self.id = id
        self.name = name
        self.isCurrent = isCurrent
        self.upstream = upstream
        self.latestCommitHash = latestCommitHash
        self.latestCommitMessage = latestCommitMessage
    }
}

/// Git 提交模型
public struct GitCommit: Identifiable, Codable, Hashable {
    public let id: String
    public let hash: String
    public let author: String
    public let email: String
    public let date: Date
    public let message: String
    public let body: String
    public let refs: [String]
    public let tags: [String]

    /// 父提交的哈希列表
    /// - 普通提交：1 个父提交
    /// - 合并提交：2 个或更多父提交
    /// - 初始提交：空数组
    public let parentHashes: [String]

    /// 是否为初始提交（没有父提交）
    public var isInitialCommit: Bool {
        parentHashes.isEmpty
    }

    /// 是否为合并提交（有多个父提交）
    public var isMergeCommit: Bool {
        parentHashes.count > 1
    }

    public init(id: String, hash: String, author: String, email: String, date: Date, message: String, body: String, refs: [String], tags: [String], parentHashes: [String] = []) {
        self.id = id
        self.hash = hash
        self.author = author
        self.email = email
        self.date = date
        self.message = message
        self.body = body
        self.refs = refs
        self.tags = tags
        self.parentHashes = parentHashes
    }
}

/// Git 差异文件模型
public struct GitDiffFile: Identifiable, Codable, Hashable {
    public let id: String
    public let file: String
    public let changeType: String
    public let diff: String

    /// 是否为二进制文件（图片、字体、压缩包等）
    public let isBinary: Bool

    public init(id: String, file: String, changeType: String, diff: String, isBinary: Bool = false) {
        self.id = id
        self.file = file
        self.changeType = changeType
        self.diff = diff
        self.isBinary = isBinary
    }

    /// 常见的图片文件扩展名
    public static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif",
        "ico", "icns", "webp", "svg", "heic", "heif", "avif",
    ]

    /// 常见的二进制文件扩展名
    public static let binaryExtensions: Set<String> = [
        // 图片
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif",
        "ico", "icns", "webp", "heic", "heif", "avif",
        // 字体
        "ttf", "otf", "woff", "woff2", "eot",
        // 压缩包
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "pkg",
        // 编译产物
        "o", "so", "dylib", "a", "lib", "exe", "dll",
        // 文档
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        // 音视频
        "mp3", "mp4", "wav", "avi", "mov", "mkv", "flac", "ogg",
        // 数据库
        "sqlite", "db",
        // 其他
        "bin", "dat", "class", "jar", "nib", "storyboardc",
    ]

    /// 是否为图片文件（基于扩展名判断）
    public var isImage: Bool {
        let ext = (file as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    /// 基于扩展名判断是否为二进制文件
    public static func isBinaryByExtension(_ filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        return binaryExtensions.contains(ext)
    }
}

/// Git 远程仓库模型
public struct GitRemote: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let url: String
    public let fetchURL: String?
    public let pushURL: String?
    public let isDefault: Bool

    public init(id: String, name: String, url: String, fetchURL: String?, pushURL: String?, isDefault: Bool) {
        self.id = id
        self.name = name
        self.url = url
        self.fetchURL = fetchURL
        self.pushURL = pushURL
        self.isDefault = isDefault
    }
}

/// Git ahead/behind comparison against an upstream or another reference.
public struct GitAheadBehind: Codable, Hashable, Sendable {
    public let ahead: Int
    public let behind: Int
    public let hasUpstream: Bool

    public init(ahead: Int, behind: Int, hasUpstream: Bool) {
        self.ahead = ahead
        self.behind = behind
        self.hasUpstream = hasUpstream
    }

    public static let noUpstream = GitAheadBehind(ahead: 0, behind: 0, hasUpstream: false)
}

/// Commit summary used by branch comparison views.
public struct GitBranchCompareCommit: Identifiable, Codable, Hashable, Sendable {
    public let hash: String
    public let author: String
    public let date: Date
    public let subject: String

    public init(hash: String, author: String, date: Date, subject: String) {
        self.hash = hash
        self.author = author
        self.date = date
        self.subject = subject
    }

    public var id: String { hash }
}

/// File summary used by branch comparison views.
public struct GitBranchCompareFile: Identifiable, Codable, Hashable, Sendable {
    public let status: String
    public let path: String
    public let oldPath: String?

    public init(status: String, path: String, oldPath: String? = nil) {
        self.status = status
        self.path = path
        self.oldPath = oldPath
    }

    public var id: String {
        if let oldPath {
            return "\(status):\(oldPath)->\(path)"
        }
        return "\(status):\(path)"
    }
}

/// Branch comparison result equivalent to `rev-list --left-right --count`,
/// `log base..head`, and `diff --name-status base...head`.
public struct GitBranchCompare: Codable, Hashable, Sendable {
    public let base: String
    public let head: String
    public let ahead: Int
    public let behind: Int
    public let commits: [GitBranchCompareCommit]
    public let files: [GitBranchCompareFile]

    public init(
        base: String,
        head: String,
        ahead: Int,
        behind: Int,
        commits: [GitBranchCompareCommit],
        files: [GitBranchCompareFile]
    ) {
        self.base = base
        self.head = head
        self.ahead = ahead
        self.behind = behind
        self.commits = commits
        self.files = files
    }
}

/// Git submodule summary.
public struct GitSubmoduleInfo: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Hashable, Sendable {
        case initialized
        case uninitialized
        case modified
        case conflicted
    }

    public let path: String
    public let commitHash: String
    public let status: Status
    public let description: String?

    public init(path: String, commitHash: String, status: Status, description: String? = nil) {
        self.path = path
        self.commitHash = commitHash
        self.status = status
        self.description = description
    }
}

/// Patch application mode for index-only hunk staging operations.
public enum GitPatchApplyMode: Codable, Hashable, Sendable {
    case stage
    case unstage
}

/// Git 标签模型 (如果需要 struct)
public struct GitTag: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let commitHash: String

    public init(id: String, name: String, commitHash: String) {
        self.id = id
        self.name = name
        self.commitHash = commitHash
    }
}

// MARK: - GitCommit 扩展

/// GitCommit 的 Co-Authored-By 支持扩展
public extension GitCommit {
    /// 从提交消息中解析的共同作者列表
    var coAuthors: [String] {
        parseCoAuthors(from: body.isEmpty ? message : body)
    }

    /// 所有作者的格式化字符串（主要作者 + 共同作者）
    var allAuthors: String {
        let all = [author] + coAuthors
        return all.joined(separator: " + ")
    }

    /// 解析 Co-Authored-By 信息的私有方法
    /// - Parameter text: 要解析的文本
    /// - Returns: 共同作者名称数组
    private func parseCoAuthors(from text: String) -> [String] {
        let lines = text.split(separator: "\n")
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().starts(with: "co-authored-by:") {
                // 解析 "Co-Authored-By: Name <email>" 格式
                let authorPart = trimmed.dropFirst("Co-Authored-By:".count).trimmingCharacters(in: .whitespaces)
                // 提取姓名部分（去掉邮箱）
                if let angleBracketIndex = authorPart.firstIndex(of: "<") {
                    let name = authorPart[..<angleBracketIndex].trimmingCharacters(in: .whitespaces)
                    return name.isEmpty ? nil : name
                }
                return authorPart
            }
            return nil
        }
    }
}
