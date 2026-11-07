import Clibgit2
import Foundation

/// 单行 blame 结果
public struct GitBlameLine: Identifiable, Codable, Hashable, Sendable {
    /// 行号（从 1 开始）
    public let lineNumber: Int
    /// 该行最终内容的 commit hash
    public let commitHash: String
    /// 作者名称
    public let author: String
    /// 作者邮箱
    public let authorEmail: String
    /// 作者时间
    public let authorDate: Date
    /// 行内容
    public let content: String
    /// 是否为边界提交（仓库根提交之前）
    public let isBoundary: Bool

    public init(
        lineNumber: Int,
        commitHash: String,
        author: String,
        authorEmail: String,
        authorDate: Date,
        content: String,
        isBoundary: Bool
    ) {
        self.lineNumber = lineNumber
        self.commitHash = commitHash
        self.author = author
        self.authorEmail = authorEmail
        self.authorDate = authorDate
        self.content = content
        self.isBoundary = isBoundary
    }

    public var id: Int { lineNumber }
}

extension LibGit2 {
    /// 对指定文件执行 git blame，等价于 `git blame <file>`。
    public static func blame(
        file filePath: String,
        at path: String,
        fromCommit commitHash: String? = nil
    ) throws -> [GitBlameLine] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var opts = git_blame_options()
            git_blame_options_init(&opts, UInt32(GIT_BLAME_OPTIONS_VERSION))

            if let commitHash {
                var oid = git_oid()
                guard git_oid_fromstr(&oid, commitHash) == 0 else {
                    throw LibGit2Error.invalidValue
                }
                opts.newest_commit = oid
            }

            var blame: OpaquePointer?
            defer { if blame != nil { git_blame_free(blame) } }

            let result = filePath.withCString { filePathC in
                git_blame_file(&blame, repo, filePathC, &opts)
            }

            guard result == 0, let blamePtr = blame else {
                throw LibGit2Error.invalidValue
            }

            let hunkCount = git_blame_get_hunk_count(blamePtr)
            var lines: [GitBlameLine] = []

            // 读取文件内容
            let fullContent = fileContentFromWorkingTree(filePath: filePath, repoPath: path)
                ?? fileContentFromHEAD(filePath: filePath, repo: repo)
            let contentLines = fullContent.components(separatedBy: "\n")

            for i in 0..<hunkCount {
                guard let hunk = git_blame_get_hunk_byindex(blamePtr, i) else { continue }

                let hunkStart = Int(hunk.pointee.final_start_line_number)
                let lineCount = Int(hunk.pointee.lines_in_hunk)
                let isBoundary = hunk.pointee.boundary != 0

                let author: String
                let authorEmail: String
                let authorDate: Date

                if let sig = hunk.pointee.final_signature {
                    author = sig.pointee.name.map { String(cString: $0) } ?? ""
                    authorEmail = sig.pointee.email.flatMap { String(cString: $0) } ?? ""
                    authorDate = Date(timeIntervalSince1970: TimeInterval(sig.pointee.when.time))
                } else {
                    author = ""
                    authorEmail = ""
                    authorDate = Date(timeIntervalSince1970: 0)
                }

                let commitHashStr = oidToString(hunk.pointee.final_commit_id)

                for lineOffset in 0..<lineCount {
                    let lineNumber = hunkStart + lineOffset
                    let content: String
                    let lineIndex = lineNumber - 1
                    if lineIndex >= 0 && lineIndex < contentLines.count {
                        content = contentLines[lineIndex]
                    } else {
                        content = ""
                    }

                    lines.append(GitBlameLine(
                        lineNumber: lineNumber,
                        commitHash: commitHashStr,
                        author: author,
                        authorEmail: authorEmail,
                        authorDate: authorDate,
                        content: content,
                        isBoundary: isBoundary
                    ))
                }
            }

            return lines.sorted { $0.lineNumber < $1.lineNumber }
        }
    }

    // MARK: - Private

    private static func fileContentFromWorkingTree(filePath: String, repoPath: String) -> String? {
        let fullPath = (repoPath as NSString).appendingPathComponent(filePath)
        return try? String(contentsOfFile: fullPath, encoding: .utf8)
    }

    private static func fileContentFromHEAD(filePath: String, repo: OpaquePointer) -> String {
        var headOID = git_oid()
        guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0 else { return "" }

        var commit: OpaquePointer?
        defer { if commit != nil { git_commit_free(commit) } }
        guard git_commit_lookup(&commit, repo, &headOID) == 0, let commit else { return "" }

        var tree: OpaquePointer?
        defer { if tree != nil { git_tree_free(tree) } }
        guard git_commit_tree(&tree, commit) == 0 else { return "" }

        var entry: OpaquePointer?
        defer { if entry != nil { git_tree_entry_free(entry) } }
        guard git_tree_entry_bypath(&entry, tree, filePath) == 0, let entry else { return "" }

        let entryOID = git_tree_entry_id(entry)
        var blob: OpaquePointer?
        defer { if blob != nil { git_blob_free(blob) } }
        guard git_blob_lookup(&blob, repo, entryOID) == 0, let blob else { return "" }

        guard let contentPtr = git_blob_rawcontent(blob) else { return "" }
        let size = git_blob_rawsize(blob)
        return String(data: Data(bytes: contentPtr, count: Int(size)), encoding: .utf8) ?? ""
    }
}
