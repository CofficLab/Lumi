import Foundation
import Clibgit2
import OSLog

/// LibGit2 状态检查操作扩展
extension LibGit2 {
    /// 检查是否有未提交的变更
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    /// - Returns: 如果有未提交的变更返回 true
    public static func hasUncommittedChanges(at path: String, verbose: Bool = true) throws -> Bool {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var statusOpts = git_status_options()
            git_status_init_options(&statusOpts, UInt32(GIT_STATUS_OPTIONS_VERSION))
            statusOpts.flags = GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue |
                              GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue
            // 注意：不包含 GIT_STATUS_OPT_INCLUDE_UNTRACKED，所以未跟踪文件不会被计算在内

            var statusList: OpaquePointer? = nil
            defer { if statusList != nil { git_status_list_free(statusList) } }

            let result = git_status_list_new(&statusList, repo, &statusOpts)

            if result != 0 {
                throw LibGit2Error.cannotGetStatus
            }

            guard let statusList else { return false }
            let count = git_status_list_entrycount(statusList)

            if verbose { os_log("\(t)Uncommitted changes count: \(count)") }

            return count > 0
        }
    }

    /// 获取状态信息（类似 git status）
    /// - Parameter path: 仓库路径
    /// - Returns: 状态信息字符串
    public static func getStatus(at path: String, verbose: Bool = true) throws -> String {
        return try LibGit2.serialized(at: path) {
            if verbose { os_log("\(t) Getting status at path: \(path)") }
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var statusOpts = git_status_options()
            git_status_init_options(&statusOpts, UInt32(GIT_STATUS_OPTIONS_VERSION))
            statusOpts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                              GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue

            var statusList: OpaquePointer? = nil
            defer { if statusList != nil { git_status_list_free(statusList) } }

            let result = git_status_list_new(&statusList, repo, &statusOpts)

            if result != 0 {
                throw LibGit2Error.cannotGetStatus
            }

            var output = ""
            guard let statusList else { return "" }
            let count = git_status_list_entrycount(statusList)

            for i in 0..<count {
                if let entry = git_status_byindex(statusList, i) {
                    let status = entry.pointee.status

                    // 解析状态标志
                    var statusStr = ""
                    let statusRaw = status.rawValue
                    if statusRaw & GIT_STATUS_INDEX_NEW.rawValue != 0 {
                        statusStr += "A"
                    } else if statusRaw & GIT_STATUS_INDEX_MODIFIED.rawValue != 0 {
                        statusStr += "M"
                    } else if statusRaw & GIT_STATUS_INDEX_DELETED.rawValue != 0 {
                        statusStr += "D"
                    } else if statusRaw & GIT_STATUS_INDEX_RENAMED.rawValue != 0 {
                        statusStr += "R"
                    } else if statusRaw & GIT_STATUS_INDEX_TYPECHANGE.rawValue != 0 {
                        statusStr += "T"
                    } else if statusRaw & GIT_STATUS_WT_NEW.rawValue != 0 {
                        // 未跟踪文件在索引中显示为 ?
                        statusStr += "?"
                    } else {
                        statusStr += " "
                    }

                    if statusRaw & GIT_STATUS_WT_NEW.rawValue != 0 {
                        statusStr += "?"
                    } else if statusRaw & GIT_STATUS_WT_MODIFIED.rawValue != 0 {
                        statusStr += "M"
                    } else if statusRaw & GIT_STATUS_WT_DELETED.rawValue != 0 {
                        statusStr += "D"
                    } else if statusRaw & GIT_STATUS_WT_RENAMED.rawValue != 0 {
                        statusStr += "R"
                    } else if statusRaw & GIT_STATUS_WT_TYPECHANGE.rawValue != 0 {
                        statusStr += "T"
                    } else if statusRaw & GIT_STATUS_IGNORED.rawValue != 0 {
                        statusStr += "!"
                    } else {
                        statusStr += " "
                    }

                    // 获取文件路径
                    let pathPtr = entry.pointee.head_to_index?.pointee.old_file.path
                               ?? entry.pointee.index_to_workdir?.pointee.old_file.path

                    if let filePath = pathPtr {
                        let fileName = String(cString: filePath)
                        output += "\(statusStr) \(fileName)\n"
                    }
                }
            }

            return output
        }
    }

    /// 获取简洁状态信息（类似 git status --porcelain）
    /// - Parameter path: 仓库路径
    /// - Returns: 简洁状态信息字符串
    static func getStatusPorcelain(at path: String) throws -> String {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var statusOpts = git_status_options()
        git_status_init_options(&statusOpts, UInt32(GIT_STATUS_OPTIONS_VERSION))
        statusOpts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                          GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue |
                          GIT_STATUS_OPT_RECURSE_IGNORED_DIRS.rawValue

        var statusList: OpaquePointer? = nil
        defer { if statusList != nil { git_status_list_free(statusList) } }

        let result = git_status_list_new(&statusList, repo, &statusOpts)

        if result != 0 {
            throw LibGit2Error.cannotGetStatus
        }

        var output = ""
        guard let statusList else { return "" }
        let count = git_status_list_entrycount(statusList)

        for i in 0..<count {
            if let entry = git_status_byindex(statusList, i) {
                let status = entry.pointee.status

                let statusRaw = status.rawValue
                // 解析状态标志（porcelain 格式）
                var indexStatus: Character = " "
                var worktreeStatus: Character = " "

                if statusRaw & GIT_STATUS_INDEX_NEW.rawValue != 0 {
                    indexStatus = "A"
                } else if statusRaw & GIT_STATUS_INDEX_MODIFIED.rawValue != 0 {
                    indexStatus = "M"
                } else if statusRaw & GIT_STATUS_INDEX_DELETED.rawValue != 0 {
                    indexStatus = "D"
                } else if statusRaw & GIT_STATUS_INDEX_RENAMED.rawValue != 0 {
                    indexStatus = "R"
                } else if statusRaw & GIT_STATUS_INDEX_TYPECHANGE.rawValue != 0 {
                    indexStatus = "T"
                }

                // 对于未跟踪文件，索引状态也是 ?
                if statusRaw & GIT_STATUS_WT_NEW.rawValue != 0 {
                    indexStatus = "?"
                }

                if statusRaw & GIT_STATUS_WT_NEW.rawValue != 0 {
                    worktreeStatus = "?"
                } else if statusRaw & GIT_STATUS_WT_MODIFIED.rawValue != 0 {
                    worktreeStatus = "M"
                } else if statusRaw & GIT_STATUS_WT_DELETED.rawValue != 0 {
                    worktreeStatus = "D"
                } else if statusRaw & GIT_STATUS_WT_RENAMED.rawValue != 0 {
                    worktreeStatus = "R"
                } else if statusRaw & GIT_STATUS_WT_TYPECHANGE.rawValue != 0 {
                    worktreeStatus = "T"
                } else if statusRaw & GIT_STATUS_IGNORED.rawValue != 0 {
                    worktreeStatus = "!"
                }

                // 获取文件路径
                let pathPtr = entry.pointee.head_to_index?.pointee.old_file.path
                           ?? entry.pointee.index_to_workdir?.pointee.old_file.path

                if let filePath = pathPtr {
                    let fileName = String(cString: filePath)
                    output += "\(indexStatus)\(worktreeStatus) \(fileName)\n"
                }
            }
        }

        return output
    }

    /// 获取已暂存的文件列表
    /// - Parameter path: 仓库路径
    /// - Returns: 已暂存的文件路径列表
    static func getStagedFiles(at path: String) throws -> [String] {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var statusOpts = git_status_options()
        git_status_init_options(&statusOpts, UInt32(GIT_STATUS_OPTIONS_VERSION))
        statusOpts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                          GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue |
                          GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue |
                          GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue

        var statusList: OpaquePointer? = nil
        defer { if statusList != nil { git_status_list_free(statusList) } }

        let result = git_status_list_new(&statusList, repo, &statusOpts)

        if result != 0 {
            throw LibGit2Error.cannotGetStatus
        }

        var files: [String] = []
        guard let statusList else { return [] }
        let count = git_status_list_entrycount(statusList)

        for i in 0..<count {
            if let entry = git_status_byindex(statusList, i) {
                let status = entry.pointee.status
                let statusRaw = status.rawValue
                // 检查是否有索引变更
                if statusRaw & GIT_STATUS_INDEX_NEW.rawValue != 0 ||
                   statusRaw & GIT_STATUS_INDEX_MODIFIED.rawValue != 0 ||
                   statusRaw & GIT_STATUS_INDEX_DELETED.rawValue != 0 ||
                   statusRaw & GIT_STATUS_INDEX_RENAMED.rawValue != 0 ||
                   statusRaw & GIT_STATUS_INDEX_TYPECHANGE.rawValue != 0 {

                    let pathPtr = entry.pointee.index_to_workdir?.pointee.old_file.path
                               ?? entry.pointee.head_to_index?.pointee.old_file.path

                    if let filePath = pathPtr {
                        files.append(String(cString: filePath))
                    }
                }
            }
        }

        return files
    }

    /// 获取未暂存的文件列表
    /// - Parameter path: 仓库路径
    /// - Returns: 未暂存的文件路径列表
    static func getUnstagedFiles(at path: String) throws -> [String] {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var statusOpts = git_status_options()
        git_status_init_options(&statusOpts, UInt32(GIT_STATUS_OPTIONS_VERSION))
        statusOpts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                          GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue

        var statusList: OpaquePointer? = nil
        defer { if statusList != nil { git_status_list_free(statusList) } }

        let result = git_status_list_new(&statusList, repo, &statusOpts)

        if result != 0 {
            throw LibGit2Error.cannotGetStatus
        }

        var files: [String] = []
        guard let statusList else { return [] }
        let count = git_status_list_entrycount(statusList)

        for i in 0..<count {
            if let entry = git_status_byindex(statusList, i) {
                let status = entry.pointee.status
                let statusRaw = status.rawValue
                // 检查是否有工作区变更
                if statusRaw & GIT_STATUS_WT_NEW.rawValue != 0 ||
                   statusRaw & GIT_STATUS_WT_MODIFIED.rawValue != 0 ||
                   statusRaw & GIT_STATUS_WT_DELETED.rawValue != 0 ||
                   statusRaw & GIT_STATUS_WT_RENAMED.rawValue != 0 ||
                   statusRaw & GIT_STATUS_WT_TYPECHANGE.rawValue != 0 {

                    let pathPtr = entry.pointee.index_to_workdir?.pointee.old_file.path

                    if let filePath = pathPtr {
                        files.append(String(cString: filePath))
                    }
                }
            }
        }

        return files
    }

    /// 检查是否有文件待提交
    /// - Parameter path: 仓库路径
    /// - Returns: 如果有待提交的文件返回 true
    static func hasFilesToCommit(at path: String) throws -> Bool {
        let stagedFiles = try getStagedFiles(at: path)
        return !stagedFiles.isEmpty
    }
}
