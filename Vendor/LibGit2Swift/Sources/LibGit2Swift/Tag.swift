import Foundation
import Clibgit2
import OSLog

/// LibGit2 标签操作扩展
extension LibGit2 {
    /// 获取标签列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - commitHash: 可选的提交哈希，只返回指向该提交的标签
    /// - Returns: 标签名称列表
    public static func getTags(at path: String, for commitHash: String? = nil) throws -> [String] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var tagNames = git_strarray()
            defer { git_strarray_free(&tagNames) }

            let result = git_tag_list(&tagNames, repo)

            if result != 0 {
                return []
            }

            var tags: [String] = []
            let count = tagNames.count
            for i in 0..<count {
                if let namePtr = tagNames.strings[i] {
                    let tagName = String(cString: namePtr)

                    // 如果指定了 commitHash，检查标签是否指向该提交
                    if let commitHash = commitHash {
                        if (try? tagPointsToCommit(tagName, commitHash: commitHash, at: path)) == true {
                            tags.append(tagName)
                        }
                    } else {
                        tags.append(tagName)
                    }
                }
            }

            return tags
        }
    }

    /// 创建标签
    /// - Parameters:
    ///   - name: 标签名称
    ///   - message: 标签信息（nil 表示轻量标签）
    ///   - commitHash: 提交哈希（nil 表示使用 HEAD）
    ///   - path: 仓库路径
    public static func createTag(named name: String, message: String? = nil, at commitHash: String? = nil, in path: String, verbose: Bool) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Creating tag: %{public}@", name) }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 获取目标 commit
            var targetOID = git_oid()

            if let commitHash = commitHash {
                guard git_oid_fromstr(&targetOID, commitHash) == 0 else {
                    throw LibGit2Error.invalidValue
                }
            } else {
                if git_reference_name_to_id(&targetOID, repo, "HEAD") != 0 {
                    throw LibGit2Error.cannotGetHEAD
                }
            }

            var targetCommit: OpaquePointer? = nil
            defer { if targetCommit != nil { git_commit_free(targetCommit) } }

            guard git_commit_lookup(&targetCommit, repo, &targetOID) == 0,
                  let commit = targetCommit else {
                throw LibGit2Error.invalidValue
            }

            // 创建签名
            let signature = try createSignature(at: path, verbose: verbose)
            defer { git_signature_free(signature) }

            var tagOID = git_oid()

            let result: Int32
            if let message = message {
                // 创建带注释的标签
                result = git_tag_create(
                    &tagOID,
                    repo,
                    name,
                    commit,
                    signature,
                    message,
                    0
                )
            } else {
                // 创建轻量标签
                result = git_tag_create_lightweight(
                    &tagOID,
                    repo,
                    name,
                    commit,
                    0
                )
            }

            if result != 0 {
                throw LibGit2Error.invalidValue
            }

            if verbose { os_log("🐚 LibGit2: Tag created: %{public}@", name) }
        }
    }

    /// 删除标签
    /// - Parameters:
    ///   - name: 标签名称
    ///   - path: 仓库路径
    public static func deleteTag(named name: String, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Deleting tag: %{public}@", name) }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let result = git_tag_delete(repo, name)

            if result != 0 {
                throw LibGit2Error.invalidValue
            }

            if verbose { os_log("🐚 LibGit2: Tag deleted: %{public}@", name) }
        }
    }

    /// 获取标签指向的提交哈希
    /// - Parameters:
    ///   - name: 标签名称
    ///   - path: 仓库路径
    /// - Returns: 提交哈希
    static func getTagTarget(name: String, at path: String) throws -> String {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var tagRef: OpaquePointer? = nil
        defer { if tagRef != nil { git_reference_free(tagRef) } }

        let tagName = "refs/tags/\(name)"
        let result = git_reference_lookup(&tagRef, repo, tagName)

        if result != 0 {
            throw LibGit2Error.invalidValue
        }

        guard let ref = tagRef else {
            throw LibGit2Error.invalidReference
        }

        // 解析标签
        var tag: OpaquePointer? = nil
        defer { if tag != nil { git_tag_free(tag) } }

        if let target = git_reference_target(ref) {
            if git_tag_lookup(&tag, repo, target) == 0, let tagPtr = tag {
                // 带注释的标签
                let targetOID = git_tag_target_id(tagPtr)
                guard let targetOID else { return "" }
                return oidToString(targetOID.pointee)
            } else {
                // 轻量标签，直接指向 commit
                return oidToString(target.pointee)
            }
        }
        throw LibGit2Error.invalidReference
    }

    // MARK: - 私有辅助方法

    /// 检查标签是否指向指定的提交
    private static func tagPointsToCommit(_ tagName: String, commitHash: String, at path: String) throws -> Bool {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var targetOID = git_oid()

        guard git_oid_fromstr(&targetOID, commitHash) == 0 else {
            return false
        }

        let tagNameRef = "refs/tags/\(tagName)"

        // 首先查找标签引用
        var reference: OpaquePointer? = nil
        defer { if reference != nil { git_reference_free(reference) } }

        guard git_reference_lookup(&reference, repo, tagNameRef) == 0, let ref = reference else {
            return false
        }

        guard let tagRefOID = git_reference_target(ref) else {
            return false
        }

        // 尝试查找带注释的标签
        var tag: OpaquePointer? = nil
        defer { if tag != nil { git_tag_free(tag) } }

        if git_tag_lookup(&tag, repo, tagRefOID) == 0, let tagPtr = tag {
            // 带注释的标签，获取它指向的 commit OID
            let tagTargetOID = git_tag_target_id(tagPtr)
            return git_oid_equal(tagTargetOID, &targetOID) == 1
        } else {
            // 轻量标签，直接比较 OID
            return git_oid_equal(tagRefOID, &targetOID) == 1
        }
    }
}
