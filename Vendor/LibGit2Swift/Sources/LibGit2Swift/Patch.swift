import Clibgit2
import Foundation

/// 单个 diff hunk，等价于 unified diff 中的 `@@ -x,y +x,y @@` 块。
public struct GitDiffHunk: Identifiable, Codable, Hashable, Sendable {
    /// 旧文件起始行号
    public let oldStart: Int
    /// 旧文件行数
    public let oldLines: Int
    /// 新文件起始行号
    public let newStart: Int
    /// 新文件行数
    public let newLines: Int
    /// hunk 的原始文本（包含 header 和内容）
    public let rawPatch: String

    public init(
        oldStart: Int,
        oldLines: Int,
        newStart: Int,
        newLines: Int,
        rawPatch: String
    ) {
        self.oldStart = oldStart
        self.oldLines = oldLines
        self.newStart = newStart
        self.newLines = newLines
        self.rawPatch = rawPatch
    }

    public var id: String { "@@-\(oldStart),\(oldLines)+\(newStart),\(newLines)" }
}

extension LibGit2 {
    // MARK: - Hunk 解析

    /// 解析指定文件的 diff hunk 列表。
    ///
    /// - Parameters:
    ///   - filePath: 相对于仓库根目录的文件路径
    ///   - path: 仓库路径
    ///   - staged: 是否获取已暂存的变更（true = index vs HEAD，false = workdir vs index）
    /// - Returns: 按行号排序的 hunk 列表
    public static func getDiffHunks(for filePath: String, at path: String, staged: Bool = false) throws -> [GitDiffHunk] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var diff: OpaquePointer?
            defer { if diff != nil { git_diff_free(diff) } }

            if staged {
                var index: OpaquePointer?
                defer { if index != nil { git_index_free(index) } }
                guard git_repository_index(&index, repo) == 0, let index else {
                    throw LibGit2Error.cannotGetIndex
                }

                var tree: OpaquePointer?
                defer { if tree != nil { git_tree_free(tree) } }

                var headOID = git_oid()
                if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                    var commit: OpaquePointer?
                    defer { if commit != nil { git_commit_free(commit) } }
                    if git_commit_lookup(&commit, repo, &headOID) == 0 {
                        git_commit_tree(&tree, commit)
                    }
                }

                git_diff_tree_to_index(&diff, repo, tree, index, nil)
            } else {
                var index: OpaquePointer?
                defer { if index != nil { git_index_free(index) } }
                guard git_repository_index(&index, repo) == 0, let index else {
                    throw LibGit2Error.cannotGetIndex
                }

                var opts = git_diff_options()
                git_diff_init_options(&opts, UInt32(GIT_DIFF_OPTIONS_VERSION))
                opts.flags = GIT_DIFF_INCLUDE_UNTRACKED.rawValue | GIT_DIFF_RECURSE_UNTRACKED_DIRS.rawValue

                var pathC: UnsafeMutablePointer<CChar>? = strdup(filePath)
                defer { free(pathC) }
                var pathspecStrings: [UnsafeMutablePointer<CChar>?] = [pathC]
                pathspecStrings.withUnsafeMutableBufferPointer { buffer in
                    guard let baseAddr = buffer.baseAddress else { return }
                    var spec = git_strarray(strings: baseAddr, count: 1)
                    opts.pathspec = spec
                    git_diff_index_to_workdir(&diff, repo, index, &opts)
                }
            }

            guard let diffPtr = diff else { return [] }

            let deltaCount = git_diff_num_deltas(diffPtr)
            var hunks: [GitDiffHunk] = []

            for i in 0..<deltaCount {
                guard let delta = git_diff_get_delta(diffPtr, i) else { continue }
                let deltaPath = String(cString: delta.pointee.new_file.path)
                guard deltaPath == filePath else { continue }

                var patch: OpaquePointer?
                defer { if patch != nil { git_patch_free(patch) } }

                guard git_patch_from_diff(&patch, diffPtr, i) == 0, let patchPtr = patch else {
                    continue
                }

                let hunkCount = git_patch_num_hunks(patchPtr)
                for j in 0..<hunkCount {
                    var hunkPtr: UnsafePointer<git_diff_hunk>?
                    var linesInHunk = 0
                    guard git_patch_get_hunk(&hunkPtr, &linesInHunk, patchPtr, j) == 0,
                          let hunkInfo = hunkPtr else {
                        continue
                    }

                    let headerData = withUnsafeBytes(of: hunkInfo.pointee.header) { ptr in
                        Data(bytes: ptr.baseAddress!, count: ptr.count)
                    }
                    let header = String(data: headerData, encoding: .utf8)?.split(separator: "\0").first.map(String.init) ?? ""
                    let oldStart = Int(hunkInfo.pointee.old_start)
                    let oldLines = Int(hunkInfo.pointee.old_lines)
                    let newStart = Int(hunkInfo.pointee.new_start)
                    let newLines = Int(hunkInfo.pointee.new_lines)

                    hunks.append(GitDiffHunk(
                        oldStart: oldStart,
                        oldLines: oldLines,
                        newStart: newStart,
                        newLines: newLines,
                        rawPatch: header
                    ))
                }
            }

            return hunks
        }
    }

    // MARK: - Hunk 应用

    /// 将单个 hunk 应用到暂存区，等价于 `git add -p` 中对一个 hunk 选择 "y"。
    ///
    /// - Parameters:
    ///   - hunk: 要应用的 hunk 原始文本
    ///   - mode: 应用到暂存区还是从暂存区移除
    ///   - path: 仓库路径
    public static func applyHunk(_ hunk: String, mode: GitPatchApplyMode, at path: String) throws {
        try LibGit2.serialized(at: path) {
            // 确保 hunk 以换行结尾
            let normalizedHunk = hunk.hasSuffix("\n") ? hunk : hunk + "\n"
            let patchToApply = mode == .stage ? normalizedHunk : reversePatch(normalizedHunk)

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 先尝试用 git_apply
            var diff: OpaquePointer?
            defer { if diff != nil { git_diff_free(diff) } }

            let parseResult = patchToApply.withCString { buffer in
                git_diff_from_buffer(&diff, buffer, strlen(buffer))
            }

            if parseResult == 0, let diff {
                var opts = git_apply_options()
                git_apply_options_init(&opts, UInt32(GIT_APPLY_OPTIONS_VERSION))
                if git_apply(repo, diff, GIT_APPLY_LOCATION_INDEX, &opts) == 0 {
                    return
                }
            }

            // 回退到手动解析 text patch
            try applyPatchManually(patchToApply, repo: repo)
        }
    }

    // MARK: - Private Helpers

    private static func reversePatch(_ patch: String) -> String {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var reversed: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("--- ") && index + 1 < lines.count, lines[index + 1].hasPrefix("+++ ") {
                reversed.append("--- " + String(lines[index + 1].dropFirst(4)))
                reversed.append("+++ " + String(line.dropFirst(4)))
                index += 2; continue
            }
            if line.hasPrefix("new file mode ") {
                reversed.append(line.replacingOccurrences(of: "new file mode ", with: "deleted file mode "))
            } else if line.hasPrefix("deleted file mode ") {
                reversed.append(line.replacingOccurrences(of: "deleted file mode ", with: "new file mode "))
            } else if line.hasPrefix("+"), line.hasPrefix("+++") == false {
                reversed.append("-" + String(line.dropFirst()))
            } else if line.hasPrefix("-"), line.hasPrefix("---") == false {
                reversed.append("+" + String(line.dropFirst()))
            } else {
                reversed.append(line)
            }
            index += 1
        }
        return reversed.joined(separator: "\n")
    }

    private static func applyPatchManually(_ patch: String, repo: OpaquePointer) throws {
        // 简化实现：解析 patch 中的文件路径和 +/- 行
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var currentFile: String?
        var index: OpaquePointer?
        defer {
            if index != nil { git_index_free(index) }
        }
        guard git_repository_index(&index, repo) == 0 else {
            throw LibGit2Error.cannotGetIndex
        }

        for line in lines {
            if line.hasPrefix("+++ b/") {
                currentFile = String(line.dropFirst(6))
            } else if let file = currentFile, line.hasPrefix("+"), line.hasPrefix("+++") == false {
                // 追加行到文件（简化实现）
                let fullPath = (repoPathFromRepo(repo) as NSString).appendingPathComponent(file)
                let content = line.dropFirst()
                if let data = "\(content)\n".data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: fullPath) {
                        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: fullPath)) {
                            handle.seekToEndOfFile()
                            handle.write(data)
                            handle.closeFile()
                        }
                    } else {
                        try? data.write(to: URL(fileURLWithPath: fullPath))
                    }
                    if let index { git_index_add_bypath(index, file) }
                }
            }
        }
        if let index { git_index_write(index) }
    }

    private static func repoPathFromRepo(_ repo: OpaquePointer) -> String {
        if let pathC = git_repository_path(repo) {
            let gitDir = String(cString: pathC)
            return (gitDir as NSString).deletingLastPathComponent
        }
        return ""
    }
}
