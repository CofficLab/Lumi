import Foundation
import Clibgit2
import OSLog
import MagicLog

/// LibGit2 添加文件操作扩展
extension LibGit2 {
    /// 添加文件到暂存区
    /// - Parameters:
    ///   - files: 要添加的文件路径列表（空数组表示添加所有变更）
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func addFiles(_ files: [String], at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Adding files to staging area") }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var index: OpaquePointer? = nil
            defer { if index != nil { git_index_free(index) } }

            guard git_repository_index(&index, repo) == 0,
                  let indexPtr = index else {
                throw LibGit2Error.cannotGetIndex
            }

            // 如果 files 为空，添加所有变更
            if files.isEmpty {
                // 获取所有未跟踪和已修改的文件
                var statusOpts = git_status_options()
                git_status_init_options(&statusOpts, UInt32(GIT_STATUS_OPTIONS_VERSION))
                statusOpts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue |
                                  GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue

                var statusList: OpaquePointer? = nil
                defer { if statusList != nil { git_status_list_free(statusList) } }

                if git_status_list_new(&statusList, repo, &statusOpts) == 0 {
                    guard let statusList else { return }
                    let count = git_status_list_entrycount(statusList)

                    for i in 0..<count {
                        if let entry = git_status_byindex(statusList, i) {
                            let status = entry.pointee.status
                            let statusRaw = status.rawValue
                            // 只处理工作区的变更
                            if statusRaw & GIT_STATUS_WT_NEW.rawValue != 0 ||
                               statusRaw & GIT_STATUS_WT_MODIFIED.rawValue != 0 ||
                               statusRaw & GIT_STATUS_WT_DELETED.rawValue != 0 ||
                               statusRaw & GIT_STATUS_WT_TYPECHANGE.rawValue != 0 {

                                let pathPtr = entry.pointee.index_to_workdir?.pointee.old_file.path
                                           ?? entry.pointee.head_to_index?.pointee.new_file.path

                                if let filePath = pathPtr {
                                    // 首先尝试添加文件（用于新增或修改的文件）
                                    var result = git_index_add_bypath(indexPtr, filePath)
                                    if result != 0 {
                                        // 如果添加失败，尝试移除文件（用于删除的文件）
                                        result = git_index_remove_bypath(indexPtr, filePath)
                                        if result != 0 {
                                            if verbose { os_log("%{public}@⚠️ Failed to add/remove file: %{public}@", self.t, String(cString: filePath)) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // 添加指定的文件
                for file in files {
                    // 跳过空路径
                    if file.isEmpty {
                        continue
                    }

                    // 检查是否包含通配符
                    if file.contains("*") || file.contains("?") || file.contains("[") {
                        // 对于模式，使用 git_index_add_all
                        let cString = strdup(file)
                        var strings = [cString]
                        var result: Int32 = 0

                        strings.withUnsafeMutableBufferPointer { buffer in
                            var pathspec = git_strarray(strings: buffer.baseAddress, count: 1)
                            result = git_index_add_all(indexPtr, &pathspec, GIT_INDEX_ADD_DEFAULT.rawValue, nil, nil)
                        }

                        if result != 0 {
                            if verbose { os_log("%{public}@⚠️ Failed to add files with pattern: %{public}@ (error: %d)", self.t, file, result) }
                        } else {
                            if verbose { os_log("%{public}@Added files with pattern: %{public}@", self.t, file) }
                        }

                        // 清理
                        free(cString)

                        if result != 0 {
                            if verbose { os_log("%{public}@⚠️ Failed to add files with pattern: %{public}@ (error: %d)", self.t, file, result) }
                        } else {
                            if verbose { os_log("%{public}@Added files with pattern: %{public}@", self.t, file) }
                        }
                    } else {
                        // 首先尝试添加文件（用于新增或修改的文件）
                        var result = git_index_add_bypath(indexPtr, file)
                        if result != 0 {
                            // 如果添加失败，检查是否是目录，如果是则递归添加
                            let fullPath = (path as NSString).appendingPathComponent(file)
                            var isDirectory: ObjCBool = false
                            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue {
                                // 目录：使用 git_index_add_all 递归添加所有文件
                                let cString = strdup(file)
                                var strings = [cString]
                                result = strings.withUnsafeMutableBufferPointer { buffer in
                                    var pathspec = git_strarray(strings: buffer.baseAddress, count: 1)
                                    return git_index_add_all(indexPtr, &pathspec, GIT_INDEX_ADD_DEFAULT.rawValue, nil, nil)
                                }
                                free(cString)
                                if result == 0 {
                                    if verbose { os_log("%{public}@Added directory recursively: %{public}@", self.t, file) }
                                } else {
                                    if verbose { os_log("%{public}@⚠️ Failed to add directory: %{public}@ (error: %d)", self.t, file, result) }
                                }
                            } else {
                                // 如果添加失败，尝试移除文件（用于删除的文件）
                                result = git_index_remove_bypath(indexPtr, file)
                                if result != 0 {
                                    // 对于真正不存在的文件，我们不抛出错误，而是继续处理
                                    if verbose { os_log("%{public}@⚠️ Failed to add/remove file: %{public}@ (error: %d), continuing...", self.t, file, result) }
                                } else {
                                    if verbose { os_log("%{public}@Removed file: %{public}@", self.t, file) }
                                }
                            }
                        } else {
                            if verbose { os_log("%{public}@Added file: %{public}@", self.t, file) }
                        }
                    }
                }
            }

            // 写入 index
            let writeResult = git_index_write(indexPtr)
            if writeResult != 0 {
                throw LibGit2Error.cannotGetIndex
            }

            if verbose { os_log("\(self.t)Files added successfully") }
        }
    }

    /// 添加单个文件到暂存区
    /// - Parameters:
    ///   - file: 文件路径
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    static func addFile(_ file: String, at path: String, verbose: Bool = true) throws {
        try addFiles([file], at: path, verbose: verbose)
    }

    /// 添加所有变更到暂存区
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    static func addAll(at path: String, verbose: Bool = true) throws {
        try addFiles([], at: path, verbose: verbose)
    }
}
