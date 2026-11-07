import Foundation
import Clibgit2
import OSLog


/// LibGit2 差异操作扩展
extension LibGit2 {
    /// 将 unified diff patch 应用到 index，等价于 `git apply --cached`。
    /// `mode == .unstage` 时会先反转 patch，再应用到 index。
    public static func applyPatch(_ patch: String, mode: GitPatchApplyMode, at path: String) throws {
        try LibGit2.serialized(at: path) {
            let normalizedPatch = patch.hasSuffix("\n") ? patch : patch + "\n"
            let patchToApply = mode == .stage ? normalizedPatch : reverseUnifiedDiff(normalizedPatch)

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var diff: OpaquePointer?
            defer { if diff != nil { git_diff_free(diff) } }

            let parseResult = patchToApply.withCString { buffer in
                git_diff_from_buffer(&diff, buffer, strlen(buffer))
            }
            guard parseResult == 0, let diff else {
                try applyTextPatchToIndex(patchToApply, repo: repo)
                return
            }

            var applyOptions = git_apply_options()
            git_apply_options_init(&applyOptions, UInt32(GIT_APPLY_OPTIONS_VERSION))

            let result = git_apply(repo, diff, GIT_APPLY_LOCATION_INDEX, &applyOptions)
            if result != 0 {
                try applyTextPatchToIndex(patchToApply, repo: repo)
            }
        }
    }

    /// 获取差异文件列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - staged: 是否获取已暂存的变更（false = 工作区变更）
    /// - Returns: 差异文件列表
    public static func getDiffFileList(at path: String, staged: Bool = false) throws -> [GitDiffFile] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var diff: OpaquePointer? = nil
            defer { if diff != nil { git_diff_free(diff) } }

            if staged {
                // 获取已暂存的变更 (index vs HEAD)
                var index: OpaquePointer? = nil
                defer { if index != nil { git_index_free(index) } }

                guard git_repository_index(&index, repo) == 0 else {
                    throw LibGit2Error.cannotGetIndex
                }

                var tree: OpaquePointer? = nil
                defer { if tree != nil { git_tree_free(tree) } }

                // 获取 HEAD tree
                var headCommit: OpaquePointer? = nil
                defer { if headCommit != nil { git_commit_free(headCommit) } }

                var headOID = git_oid()

                // 检查是否有 HEAD（可能是空仓库）
                if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                    git_commit_lookup(&headCommit, repo, &headOID)

                    if let commit = headCommit {
                        git_commit_tree(&tree, commit)
                    }
                }

                // 如果没有 HEAD，创建空 diff
                if tree == nil {
                    var diffOpts = git_diff_options()
                    git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))
                    git_diff_tree_to_tree(&diff, repo, nil, nil, &diffOpts)
                } else {
                    git_diff_tree_to_index(&diff, repo, tree, index, nil)
                }
            } else {
                // 获取工作区变更 (index vs workdir)
                var index: OpaquePointer? = nil
                defer { if index != nil { git_index_free(index) } }

                guard git_repository_index(&index, repo) == 0 else {
                    throw LibGit2Error.cannotGetIndex
                }

                // 配置 diff 选项以包含未跟踪的文件
                var diffOpts = git_diff_options()
                git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))
                diffOpts.flags = GIT_DIFF_INCLUDE_UNTRACKED.rawValue |
                                GIT_DIFF_RECURSE_UNTRACKED_DIRS.rawValue

                git_diff_index_to_workdir(&diff, repo, index, &diffOpts)
            }

            guard let diffPtr = diff else {
                return []
            }

            return parseDiffFiles(diffPtr, repo: repo, path: path)
        }
    }

    /// 获取指定文件的差异内容
    /// - Parameters:
    ///   - file: 文件路径
    ///   - path: 仓库路径
    ///   - staged: 是否获取已暂存的变更
    /// - Returns: 差异内容字符串
    public static func getFileDiff(for file: String, at path: String, staged: Bool = false, ignoreWhitespace: Bool = false) throws -> String {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var diff: OpaquePointer? = nil
            defer { if diff != nil { git_diff_free(diff) } }

            if staged {
                var index: OpaquePointer? = nil
                defer { if index != nil { git_index_free(index) } }

                guard git_repository_index(&index, repo) == 0 else {
                    throw LibGit2Error.cannotGetIndex
                }

                var tree: OpaquePointer? = nil
                defer { if tree != nil { git_tree_free(tree) } }

                var headCommit: OpaquePointer? = nil
                defer { if headCommit != nil { git_commit_free(headCommit) } }

                var headOID = git_oid()

                if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                    git_commit_lookup(&headCommit, repo, &headOID)

                    if let commit = headCommit {
                        git_commit_tree(&tree, commit)
                    }
                }

                if tree != nil {
                    var diffOpts = git_diff_options()
                    git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))
                    if ignoreWhitespace {
                        diffOpts.flags |= GIT_DIFF_IGNORE_WHITESPACE.rawValue
                    }
                    let filePathCStr = strdup(file)
                    var strings: [UnsafeMutablePointer<CChar>?] = [filePathCStr]
                    strings.withUnsafeMutableBufferPointer { buffer in
                        diffOpts.pathspec.strings = buffer.baseAddress
                        diffOpts.pathspec.count = 1
                    }

                    defer {
                        free(filePathCStr)
                    }

                    git_diff_tree_to_index(&diff, repo, tree, index, &diffOpts)
                }
            } else {
                var index: OpaquePointer? = nil
                defer { if index != nil { git_index_free(index) } }

                guard git_repository_index(&index, repo) == 0 else {
                    throw LibGit2Error.cannotGetIndex
                }

                var diffOpts = git_diff_options()
                git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))
                let filePathCStr = strdup(file)
                var strings: [UnsafeMutablePointer<CChar>?] = [filePathCStr]
                strings.withUnsafeMutableBufferPointer { buffer in
                    diffOpts.pathspec.strings = buffer.baseAddress
                    diffOpts.pathspec.count = 1
                }
                diffOpts.flags = GIT_DIFF_INCLUDE_UNTRACKED.rawValue |
                                GIT_DIFF_RECURSE_UNTRACKED_DIRS.rawValue
                if ignoreWhitespace {
                    diffOpts.flags |= GIT_DIFF_IGNORE_WHITESPACE.rawValue
                }

                defer {
                    free(filePathCStr)
                }

                git_diff_index_to_workdir(&diff, repo, index, &diffOpts)
            }

            guard let diffPtr = diff else {
                return ""
            }

            // 生成 patch
            var patch: OpaquePointer? = nil
            defer { if patch != nil { git_patch_free(patch) } }

            let count = git_diff_num_deltas(diffPtr)
            var patchText = ""

            for i in 0..<count {
                // 🔧 修复：检查 delta 状态，对于未跟踪/新增文件需要特殊处理
                var deltaType: git_delta_t = GIT_DELTA_UNMODIFIED
                if let delta = git_diff_get_delta(diffPtr, i) {
                    deltaType = delta.pointee.status
                }

                if git_patch_from_diff(&patch, diffPtr, i) == 0, let patchPtr = patch {
                    var buf = git_buf()
                    defer { git_buf_dispose(&buf) }

                    if git_patch_to_buf(&buf, patchPtr) == 0 {
                        let content = String(cString: buf.ptr)
                        patchText += content
                    }
                }

                //  修复：对于未跟踪的新增文件或 diff 为空的 ADDED 文件，手动生成完整的 diff 内容
                // Libgit2 不会为 GIT_DELTA_UNTRACKED 生成 patch，需要手动构建
                if patchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let isNewOrUntracked = (deltaType == GIT_DELTA_UNTRACKED || deltaType == GIT_DELTA_ADDED)
                    if isNewOrUntracked {
                        patchText = generateAddedFileDiff(for: file, at: path)
                    }
                }
            }

            if patchText.isEmpty, staged == false {
                return try makeSyntheticWorkdirDiff(for: file, at: path)
            }

            return patchText
        }
    }

    /// 获取指定提交修改的文件列表
    /// - Parameters:
    ///   - commitHash: 提交哈希
    ///   - path: 仓库路径
    /// - Returns: 差异文件列表
    public static func getCommitDiffFiles(atCommit commitHash: String, at path: String) throws -> [GitDiffFile] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 获取指定commit
            var oid = git_oid()
            guard git_oid_fromstr(&oid, commitHash) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var commit: OpaquePointer? = nil
            defer { if commit != nil { git_commit_free(commit) } }

            guard git_commit_lookup(&commit, repo, &oid) == 0, let commitPtr = commit else {
                throw LibGit2Error.invalidValue
            }

            // 获取该commit的tree
            var commitTree: OpaquePointer? = nil
            defer { if commitTree != nil { git_tree_free(commitTree) } }

            guard git_commit_tree(&commitTree, commitPtr) == 0 else {
                throw LibGit2Error.invalidValue
            }

            // 获取父commit（用于比较）
            let parentCount = git_commit_parentcount(commitPtr)
            var diff: OpaquePointer? = nil
            defer { if diff != nil { git_diff_free(diff) } }

            if parentCount == 0 {
                // 初始提交，与空树比较
                var diffOpts = git_diff_options()
                git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))
                git_diff_tree_to_tree(&diff, repo, nil, commitTree, &diffOpts)
            } else {
                // 获取第一个父commit
                var parentOid = git_commit_parent_id(commitPtr, 0).pointee

                var parentCommit: OpaquePointer? = nil
                defer { if parentCommit != nil { git_commit_free(parentCommit) } }

                guard git_commit_lookup(&parentCommit, repo, &parentOid) == 0,
                      let parentCommitPtr = parentCommit else {
                    throw LibGit2Error.invalidValue
                }

                var parentTree: OpaquePointer? = nil
                defer { if parentTree != nil { git_tree_free(parentTree) } }

                guard git_commit_tree(&parentTree, parentCommitPtr) == 0 else {
                    throw LibGit2Error.invalidValue
                }

                // 比较父commit和当前commit的tree
                git_diff_tree_to_tree(&diff, repo, parentTree, commitTree, nil)
            }

            guard let diffPtr = diff else {
                return []
            }

            return parseDiffFiles(diffPtr, repo: repo, path: path)
        }
    }

    /// 获取两个提交之间的差异
    /// - Parameters:
    ///   - from: 起始提交哈希
    ///   - to: 结束提交哈希
    ///   - path: 仓库路径
    /// - Returns: 差异内容字符串
    public static func getDiffBetweenCommits(from: String, to: String, at path: String) throws -> String {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var fromOid = git_oid()
            var toOid = git_oid()

            guard git_oid_fromstr(&fromOid, from) == 0,
                  git_oid_fromstr(&toOid, to) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var fromCommit: OpaquePointer? = nil
            var toCommit: OpaquePointer? = nil
            defer {
                if fromCommit != nil { git_commit_free(fromCommit) }
                if toCommit != nil { git_commit_free(toCommit) }
            }

            guard git_commit_lookup(&fromCommit, repo, &fromOid) == 0,
                  git_commit_lookup(&toCommit, repo, &toOid) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var fromTree: OpaquePointer? = nil
            var toTree: OpaquePointer? = nil
            defer {
                if fromTree != nil { git_tree_free(fromTree) }
                if toTree != nil { git_tree_free(toTree) }
            }

            guard let fromCommit, let toCommit,
                  git_commit_tree(&fromTree, fromCommit) == 0,
                  git_commit_tree(&toTree, toCommit) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var diff: OpaquePointer? = nil
            defer { if diff != nil { git_diff_free(diff) } }

            git_diff_tree_to_tree(&diff, repo, fromTree, toTree, nil)

            guard let diffPtr = diff else {
                return ""
            }

            // 生成 patch
            var patch: OpaquePointer? = nil
            defer { if patch != nil { git_patch_free(patch) } }

            let count = git_diff_num_deltas(diffPtr)
            var patchText = ""

            for i in 0..<count {
                if git_patch_from_diff(&patch, diffPtr, i) == 0, let patchPtr = patch {
                    var buf = git_buf()
                    defer { git_buf_dispose(&buf) }

                    if git_patch_to_buf(&buf, patchPtr) == 0 {
                        let content = String(cString: buf.ptr)
                        patchText += content
                    }
                }
            }

            return patchText
        }
    }

    /// 获取指定提交中的文件内容
    /// - Parameters:
    ///   - commitHash: 提交哈希
    ///   - filePath: 文件路径
    ///   - repoPath: 仓库路径
    /// - Returns: 文件内容字符串
    public static func getFileContent(atCommit commitHash: String, file filePath: String, at repoPath: String) throws -> String {
        return try LibGit2.serialized(at: repoPath) {
            let data = try getFileData(atCommit: commitHash, file: filePath, at: repoPath)
            guard let content = String(data: data, encoding: .utf8) else {
                throw LibGit2Error.invalidValue
            }
            return content
        }
    }

    /// 获取指定提交中文件的原始二进制数据
    /// 支持二进制文件（图片、字体等），返回原始的 Data
    /// - Parameters:
    ///   - commitHash: 提交哈希
    ///   - filePath: 文件路径
    ///   - repoPath: 仓库路径
    /// - Returns: 文件的原始二进制数据
    public static func getFileData(atCommit commitHash: String, file filePath: String, at repoPath: String) throws -> Data {
        return try LibGit2.serialized(at: repoPath) {
            let repo = try openRepository(at: repoPath)
            defer { git_repository_free(repo) }

            var oid = git_oid()
            guard git_oid_fromstr(&oid, commitHash) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var commit: OpaquePointer? = nil
            defer { if commit != nil { git_commit_free(commit) } }

            guard git_commit_lookup(&commit, repo, &oid) == 0, let commitPtr = commit else {
                throw LibGit2Error.invalidValue
            }

            var tree: OpaquePointer? = nil
            defer { if tree != nil { git_tree_free(tree) } }

            guard git_commit_tree(&tree, commitPtr) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var treeEntry: OpaquePointer? = nil
            guard git_tree_entry_bypath(&treeEntry, tree, filePath) == 0, let entry = treeEntry else {
                throw LibGit2Error.invalidValue
            }
            defer { git_tree_entry_free(entry) }

            var blob: OpaquePointer? = nil
            let entryOid = git_tree_entry_id(entry)
            guard git_blob_lookup(&blob, repo, entryOid) == 0, let blobPtr = blob else {
                throw LibGit2Error.invalidValue
            }
            defer { git_blob_free(blobPtr) }

            let contentPtr = git_blob_rawcontent(blobPtr)
            let size = git_blob_rawsize(blobPtr)

            guard let ptr = contentPtr else {
                throw LibGit2Error.invalidValue
            }

            return Data(bytes: ptr, count: Int(size))
        }
    }

    /// 获取指定提交中文件变更的前后内容
    /// - Parameters:
    ///   - commitHash: 提交哈希
    ///   - filePath: 文件路径
    ///   - repoPath: 仓库路径
    /// - Returns: 元组 (before: 修改前的内容, after: 修改后的内容)
    public static func getFileContentChange(atCommit commitHash: String, file filePath: String, at repoPath: String) throws -> (before: String?, after: String?) {
        return try LibGit2.serialized(at: repoPath) {
            let repo = try openRepository(at: repoPath)
            defer { git_repository_free(repo) }

            // 获取指定commit
            var oid = git_oid()
            guard git_oid_fromstr(&oid, commitHash) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var commit: OpaquePointer? = nil
            defer { if commit != nil { git_commit_free(commit) } }

            guard git_commit_lookup(&commit, repo, &oid) == 0, let commitPtr = commit else {
                throw LibGit2Error.invalidValue
            }

            // 获取该commit的父commit（用于获取修改前的内容）
            let parentCount = git_commit_parentcount(commitPtr)
            var beforeContent: String? = nil
            var afterContent: String? = nil

            if parentCount > 0 {
                // 有父commit，从父commit获取文件内容
                var parentOid = git_commit_parent_id(commitPtr, 0).pointee

                var parentCommit: OpaquePointer? = nil
                defer { if parentCommit != nil { git_commit_free(parentCommit) } }

                if git_commit_lookup(&parentCommit, repo, &parentOid) == 0 {
                    guard let hashPtr = git_oid_tostr_s(&parentOid) else {
                        return (nil, nil)
                    }
                    do {
                        let parentCommitHash = String(cString: hashPtr)
                        beforeContent = try getFileContent(atCommit: parentCommitHash, file: filePath, at: repoPath)
                    } catch {
                        // 文件可能在父commit中不存在，这是正常情况
                        beforeContent = nil
                    }
                }
            } else {
                // 初始提交，没有修改前内容
                beforeContent = nil
            }

            // 从当前commit获取文件内容（修改后的内容）
            do {
                afterContent = try getFileContent(atCommit: commitHash, file: filePath, at: repoPath)
            } catch {
                // 文件被删除，这是正常情况
                afterContent = nil
            }

            return (beforeContent, afterContent)
        }
    }

    /// 获取未提交文件的前后内容
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - repoPath: 仓库路径
    /// - Returns: 元组 (before: HEAD中的内容, after: 工作区中的内容)
    public static func getUncommittedFileContentChange(for filePath: String, at repoPath: String) throws -> (before: String?, after: String?) {
        return try LibGit2.serialized(at: repoPath) {
            let repo = try openRepository(at: repoPath)
            defer { git_repository_free(repo) }

            // 获取HEAD commit（用于获取修改前的内容）
            var beforeContent: String? = nil

            var headOID = git_oid()
            if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                if let hashPtr = git_oid_tostr_s(&headOID) {
                    let headCommitHash = String(cString: hashPtr)
                    do {
                        beforeContent = try getFileContent(atCommit: headCommitHash, file: filePath, at: repoPath)
                    } catch {
                        // 文件在HEAD中不存在（新文件），这是正常情况
                        beforeContent = nil
                    }
                }
            }

            // 从工作区获取文件内容（修改后的内容）
            var afterContent: String? = nil
            let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(filePath).path

            if FileManager.default.fileExists(atPath: fullPath) {
                do {
                    afterContent = try String(contentsOfFile: fullPath, encoding: .utf8)
                } catch {
                    afterContent = nil
                }
            } else {
                // 文件被删除
                afterContent = nil
            }

            return (beforeContent, afterContent)
        }
    }

    /// 获取指定提交中特定文件的差异字符串
    /// - Parameters:
    ///   - commitHash: 提交哈希
    ///   - filePath: 文件路径
    ///   - repoPath: 仓库路径
    /// - Returns: git diff 格式的字符串
    public static func getFileDiff(atCommit commitHash: String, for filePath: String, at repoPath: String) throws -> String {
        return try LibGit2.serialized(at: repoPath) {
            let repo = try openRepository(at: repoPath)
            defer { git_repository_free(repo) }

            // 获取指定 commit
            var oid = git_oid()
            guard git_oid_fromstr(&oid, commitHash) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var commit: OpaquePointer? = nil
            defer { if commit != nil { git_commit_free(commit) } }

            guard git_commit_lookup(&commit, repo, &oid) == 0, let commitPtr = commit else {
                throw LibGit2Error.invalidValue
            }

            // 获取父 commit（用于比较）
            let parentCount = git_commit_parentcount(commitPtr)
            var diff: OpaquePointer? = nil
            defer { if diff != nil { git_diff_free(diff) } }

            if parentCount == 0 {
                // 初始提交，与空树比较
                var diffOpts = git_diff_options()
                git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))

                // 设置 pathspec 只包含目标文件
                let filePathCStr = strdup(filePath)
                var strings: [UnsafeMutablePointer<CChar>?] = [filePathCStr]
                strings.withUnsafeMutableBufferPointer { buffer in
                    diffOpts.pathspec.strings = buffer.baseAddress
                    diffOpts.pathspec.count = 1
                }
                defer { free(filePathCStr) }

                var commitTree: OpaquePointer? = nil
                defer { if commitTree != nil { git_tree_free(commitTree) } }
                guard git_commit_tree(&commitTree, commitPtr) == 0 else {
                    throw LibGit2Error.invalidValue
                }

                git_diff_tree_to_tree(&diff, repo, nil, commitTree, &diffOpts)
            } else {
                // 获取第一个父 commit
                var parentOid = git_commit_parent_id(commitPtr, 0).pointee

                var parentCommit: OpaquePointer? = nil
                defer { if parentCommit != nil { git_commit_free(parentCommit) } }

                guard git_commit_lookup(&parentCommit, repo, &parentOid) == 0,
                      let parentCommitPtr = parentCommit else {
                    throw LibGit2Error.invalidValue
                }

                var parentTree: OpaquePointer? = nil
                var commitTree: OpaquePointer? = nil
                defer {
                    if parentTree != nil { git_tree_free(parentTree) }
                    if commitTree != nil { git_tree_free(commitTree) }
                }

                guard git_commit_tree(&parentTree, parentCommitPtr) == 0,
                      git_commit_tree(&commitTree, commitPtr) == 0 else {
                    throw LibGit2Error.invalidValue
                }

                var diffOpts = git_diff_options()
                git_diff_init_options(&diffOpts, UInt32(GIT_DIFF_OPTIONS_VERSION))

                // 设置 pathspec 只包含目标文件
                let filePathCStr = strdup(filePath)
                var strings: [UnsafeMutablePointer<CChar>?] = [filePathCStr]
                strings.withUnsafeMutableBufferPointer { buffer in
                    diffOpts.pathspec.strings = buffer.baseAddress
                    diffOpts.pathspec.count = 1
                }
                defer { free(filePathCStr) }

                git_diff_tree_to_tree(&diff, repo, parentTree, commitTree, &diffOpts)
            }

            guard let diffPtr = diff else {
                return ""
            }

            // 生成 patch
            var patch: OpaquePointer? = nil
            defer { if patch != nil { git_patch_free(patch) } }

            let count = git_diff_num_deltas(diffPtr)
            var patchText = ""

            for i in 0..<count {
                if git_patch_from_diff(&patch, diffPtr, i) == 0, let patchPtr = patch {
                    var buf = git_buf()
                    defer { git_buf_dispose(&buf) }

                    if git_patch_to_buf(&buf, patchPtr) == 0 {
                        let content = String(cString: buf.ptr)
                        patchText += content
                    }
                }
            }

            return patchText
        }
    }

    // MARK: - 私有辅助方法

    /// 解析差异文件列表
    private static func parseDiffFiles(_ diff: OpaquePointer, repo: OpaquePointer, path: String) -> [GitDiffFile] {
        var files: [GitDiffFile] = []
        let count = git_diff_num_deltas(diff)

        for i in 0..<count {
            guard let delta = git_diff_get_delta(diff, i) else { continue }

            let deltaType = delta.pointee.status
            let changeType = convertDeltaStatus(deltaType)

            let oldPath = delta.pointee.old_file.path
            let newPath = delta.pointee.new_file.path

            let filePath: String
            if deltaType == GIT_DELTA_ADDED {
                guard let newPath else { continue }
                filePath = String(cString: newPath)
            } else if deltaType == GIT_DELTA_DELETED {
                guard let oldPath else { continue }
                filePath = String(cString: oldPath)
            } else if let oldPath, let newPath {
                let oldPathStr = String(cString: oldPath)
                let newPathStr = String(cString: newPath)
                filePath = oldPathStr == newPathStr ? oldPathStr : "\(oldPathStr) -> \(newPathStr)"
            } else if let oldPath {
                filePath = String(cString: oldPath)
            } else if let newPath {
                filePath = String(cString: newPath)
            } else {
                continue
            }

            // 检测二进制文件：双重检测策略
            // 1. 通过 libgit2 的 flags 判断（对已跟踪文件的变更有效）
            //    GIT_DIFF_FLAG_BINARY = 2
            let newFileFlags = delta.pointee.new_file.flags
            let oldFileFlags = delta.pointee.old_file.flags
            let flagsBinary = (newFileFlags & 2) != 0 || (oldFileFlags & 2) != 0
            // 2. 通过文件扩展名判断（对未跟踪文件等 flags 未标记的情况作为后备）
            let isBinary = flagsBinary || GitDiffFile.isBinaryByExtension(filePath)

            // 获取 diff 内容
            var diffContent = ""
            var patch: OpaquePointer? = nil
            defer { if patch != nil { git_patch_free(patch) } }

            if git_patch_from_diff(&patch, diff, i) == 0, let patchPtr = patch {
                var buf = git_buf()
                defer { git_buf_dispose(&buf) }

                if git_patch_to_buf(&buf, patchPtr) == 0 {
                    diffContent = String(cString: buf.ptr)
                }
            }

            // 🔧 修复：对于未跟踪的新增文件或 diff 为空的 ADDED 文件，手动生成完整的 diff 内容
            // Libgit2 不会为 GIT_DELTA_UNTRACKED 生成 patch，需要手动构建
            if diffContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let isNewOrUntracked = (deltaType == GIT_DELTA_UNTRACKED || deltaType == GIT_DELTA_ADDED)
                if isNewOrUntracked {
                    diffContent = generateAddedFileDiff(for: filePath, at: path)
                }
            }

            files.append(GitDiffFile(
                id: filePath,
                file: filePath,
                changeType: changeType,
                diff: diffContent,
                isBinary: isBinary
            ))
        }

        return files
    }

    /// 为新增文件手动生成完整的 diff 内容
    /// 对于未跟踪的新文件，libgit2 不会生成 patch，这里手动构建标准 git diff 格式
    /// - Parameters:
    ///   - filePath: 文件相对路径
    ///   - repoPath: 仓库根路径
    /// - Returns: 标准格式的 git diff 字符串（整个文件内容标记为新增）
    private static func generateAddedFileDiff(for filePath: String, at repoPath: String) -> String {
        let fullPath = URL(fileURLWithPath: repoPath).appendingPathComponent(filePath).path
        guard FileManager.default.fileExists(atPath: fullPath) else {
            return ""
        }

        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            return ""
        }

        if content.isEmpty {
            // 空文件，生成空 diff header
            return "diff --git a/\(filePath) b/\(filePath)\nnew file mode 100644\nindex 0000000..e69de29\n--- /dev/null\n+++ b/\(filePath)\n@@ -0,0 +1 @@\n+\n"
        }

        let lines = content.components(separatedBy: .newlines)
        let lineCount = lines.count

        // 构建标准 git diff 格式
        var diff = "diff --git a/\(filePath) b/\(filePath)\n"
        diff += "new file mode 100644\n"
        diff += "index 0000000..e69de29\n"
        diff += "--- /dev/null\n"
        diff += "+++ b/\(filePath)\n"
        diff += "@@ -0,0 +1,\(lineCount) @@\n"

        for line in lines {
            diff += "+\(line)\n"
        }

        return diff
    }

    /// 转换 delta 状态为字符串标识
    private static func convertDeltaStatus(_ status: git_delta_t) -> String {
        switch status {
        case GIT_DELTA_ADDED:
            return "A"
        case GIT_DELTA_DELETED:
            return "D"
        case GIT_DELTA_MODIFIED:
            return "M"
        case GIT_DELTA_RENAMED:
            return "R"
        case GIT_DELTA_COPIED:
            return "C"
        case GIT_DELTA_IGNORED:
            return "I"
        case GIT_DELTA_UNTRACKED:
            return "?"
        case GIT_DELTA_TYPECHANGE:
            return "T"
        default:
            return " "
        }
    }

    private static func makeSyntheticWorkdirDiff(for filePath: String, at repoPath: String) throws -> String {
        let (before, after) = try getUncommittedFileContentChange(for: filePath, at: repoPath)
        guard before != nil || after != nil else {
            return ""
        }

        return buildUnifiedDiff(filePath: filePath, before: before, after: after)
    }

    private static func buildUnifiedDiff(filePath: String, before: String?, after: String?) -> String {
        let beforeLines = normalizedDiffLines(before)
        let afterLines = normalizedDiffLines(after)

        var header = "diff --git a/\(filePath) b/\(filePath)\n"
        let body: String

        switch (before, after) {
        case (nil, let newContent?):
            header += "new file mode 100644\n"
            header += "--- /dev/null\n"
            header += "+++ b/\(filePath)\n"
            body = "@@ -0,0 +1,\(afterLines.count) @@\n" + prefixedDiffLines(newContent, prefix: "+")
        case (let oldContent?, nil):
            header += "--- a/\(filePath)\n"
            header += "+++ /dev/null\n"
            body = "@@ -1,\(beforeLines.count) +0,0 @@\n" + prefixedDiffLines(oldContent, prefix: "-")
        case (let oldContent?, let newContent?):
            header += "--- a/\(filePath)\n"
            header += "+++ b/\(filePath)\n"
            body = "@@ -1,\(beforeLines.count) +1,\(afterLines.count) @@\n"
                + prefixedDiffLines(oldContent, prefix: "-")
                + prefixedDiffLines(newContent, prefix: "+")
        default:
            return ""
        }

        return header + body
    }

    private static func normalizedDiffLines(_ text: String?) -> [String] {
        guard var lines = text?.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) else {
            return []
        }

        if text?.hasSuffix("\n") == true, lines.last == "" {
            lines.removeLast()
        }

        return lines
    }

    private static func prefixedDiffLines(_ text: String, prefix: String) -> String {
        let lines = normalizedDiffLines(text)
        if lines.isEmpty {
            return ""
        }
        return lines.map { "\(prefix)\($0)\n" }.joined()
    }

    private static func reverseUnifiedDiff(_ patch: String) -> String {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var reversed: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.hasPrefix("--- "),
               index + 1 < lines.count,
               lines[index + 1].hasPrefix("+++ ") {
                reversed.append("--- " + String(lines[index + 1].dropFirst(4)))
                reversed.append("+++ " + String(line.dropFirst(4)))
                index += 2
                continue
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

    private struct TextPatchFile {
        let path: String
        let hunks: [TextPatchHunk]
    }

    private struct TextPatchHunk {
        let oldStart: Int
        let lines: [String]
    }

    private static func applyTextPatchToIndex(_ patch: String, repo: OpaquePointer) throws {
        let patchFiles = try parseTextPatchFiles(patch)
        guard patchFiles.isEmpty == false else {
            throw LibGit2Error.invalidValue
        }

        var index: OpaquePointer?
        defer { if index != nil { git_index_free(index) } }

        guard git_repository_index(&index, repo) == 0, let index else {
            throw LibGit2Error.cannotGetIndex
        }

        for patchFile in patchFiles {
            let existingEntry = git_index_get_bypath(index, patchFile.path, 0)
            let currentContent = try indexContent(path: patchFile.path, entry: existingEntry, repo: repo)
            let updatedContent = try applyHunks(patchFile.hunks, to: currentContent)

            var entry = existingEntry?.pointee ?? git_index_entry()
            entry.mode = existingEntry?.pointee.mode ?? UInt32(GIT_FILEMODE_BLOB.rawValue)
            entry.file_size = UInt32(updatedContent.utf8.count)

            let result = patchFile.path.withCString { pathPointer in
                updatedContent.withCString { contentPointer in
                    entry.path = pathPointer
                    return git_index_add_from_buffer(index, &entry, contentPointer, strlen(contentPointer))
                }
            }

            if result != 0 {
                throw LibGit2Error.invalidValue
            }
        }

        if git_index_write(index) != 0 {
            throw LibGit2Error.cannotWriteTree
        }
    }

    private static func parseTextPatchFiles(_ patch: String) throws -> [TextPatchFile] {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var files: [TextPatchFile] = []
        var oldPath: String?
        var newPath: String?
        var hunks: [TextPatchHunk] = []
        var currentHunkStart: Int?
        var currentHunkLines: [String] = []

        func finishHunk() {
            if let currentHunkStart {
                hunks.append(TextPatchHunk(oldStart: currentHunkStart, lines: currentHunkLines))
            }
            currentHunkStart = nil
            currentHunkLines = []
        }

        func finishFile() {
            finishHunk()
            let candidatePath = (newPath != "/dev/null" ? newPath : oldPath)
            if let candidatePath, hunks.isEmpty == false {
                files.append(TextPatchFile(path: stripDiffPathPrefix(candidatePath), hunks: hunks))
            }
            oldPath = nil
            newPath = nil
            hunks = []
        }

        for line in lines {
            if line.hasPrefix("diff --git ") {
                finishFile()
            } else if line.hasPrefix("--- ") {
                oldPath = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("+++ ") {
                newPath = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("@@ ") {
                finishHunk()
                currentHunkStart = try parseHunkOldStart(line)
            } else if currentHunkStart != nil {
                currentHunkLines.append(line)
            }
        }

        finishFile()
        return files
    }

    private static func parseHunkOldStart(_ header: String) throws -> Int {
        guard let range = header.range(of: #"@@ -(\d+)(?:,\d+)? \+\d+(?:,\d+)? @@"#, options: .regularExpression) else {
            throw LibGit2Error.invalidValue
        }

        let matched = String(header[range])
        guard let startRange = matched.range(of: #"(?<=@@ -)\d+"#, options: .regularExpression),
              let start = Int(matched[startRange]) else {
            throw LibGit2Error.invalidValue
        }

        return max(start, 1)
    }

    private static func stripDiffPathPrefix(_ path: String) -> String {
        if path.hasPrefix("a/") || path.hasPrefix("b/") {
            return String(path.dropFirst(2))
        }
        return path
    }

    private static func indexContent(path: String, entry: UnsafePointer<git_index_entry>?, repo: OpaquePointer) throws -> String {
        guard let entry else {
            return ""
        }

        var oid = entry.pointee.id
        var blob: OpaquePointer?
        defer { if blob != nil { git_blob_free(blob) } }

        guard git_blob_lookup(&blob, repo, &oid) == 0,
              let blob,
              let rawContent = git_blob_rawcontent(blob) else {
            throw LibGit2Error.invalidValue
        }

        let rawSize = Int(git_blob_rawsize(blob))
        let data = Data(bytes: rawContent, count: rawSize)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func applyHunks(_ hunks: [TextPatchHunk], to content: String) throws -> String {
        let sourceLines = normalizedDiffLines(content)
        var output: [String] = []
        var sourceIndex = 0

        for hunk in hunks {
            let hunkStartIndex = max(hunk.oldStart - 1, 0)
            while sourceIndex < hunkStartIndex && sourceIndex < sourceLines.count {
                output.append(sourceLines[sourceIndex])
                sourceIndex += 1
            }

            for line in hunk.lines {
                if line.hasPrefix("\\ No newline at end of file") {
                    continue
                }

                if line.hasPrefix(" ") {
                    guard sourceIndex < sourceLines.count else { throw LibGit2Error.invalidValue }
                    output.append(sourceLines[sourceIndex])
                    sourceIndex += 1
                } else if line.hasPrefix("-") {
                    guard sourceIndex < sourceLines.count else { throw LibGit2Error.invalidValue }
                    sourceIndex += 1
                } else if line.hasPrefix("+") {
                    output.append(String(line.dropFirst()))
                }
            }
        }

        while sourceIndex < sourceLines.count {
            output.append(sourceLines[sourceIndex])
            sourceIndex += 1
        }

        return output.map { "\($0)\n" }.joined()
    }
}
