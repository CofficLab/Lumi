import Clibgit2
import Foundation

extension LibGit2 {
    /// 生成可读的版本描述，等价于 `git describe --tags`。
    ///
    /// 从指定 commit 回溯到最近的 tag，生成格式如 `v1.0.0-3-gabc1234`。
    /// 如果 commit 本身有 tag，则直接返回 tag 名称。
    ///
    /// - Parameters:
    ///   - commitHash: 提交 hash（nil 表示 HEAD）
    ///   - path: 仓库路径
    ///   - tags: 是否只匹配带注释的 tag（默认 false，即同时匹配轻量 tag）
    ///   - abbrev: 缩写 hash 长度（默认 7）
    /// - Returns: 描述字符串，如果没有 tag 则返回 nil
    @discardableResult
    public static func describe(
        at commitHash: String? = nil,
        path: String,
        annotatedOnly: Bool = false,
        abbrev: Int = 7
    ) throws -> String? {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var oid = git_oid()
            if let commitHash {
                guard git_oid_fromstr(&oid, commitHash) == 0 else {
                    throw LibGit2Error.invalidValue
                }
            } else {
                guard git_reference_name_to_id(&oid, repo, "HEAD") == 0 else {
                    throw LibGit2Error.cannotGetHEAD
                }
            }

            var commit: OpaquePointer?
            defer { if commit != nil { git_commit_free(commit) } }
            guard git_commit_lookup(&commit, repo, &oid) == 0, let commit else {
                throw LibGit2Error.invalidValue
            }

            var opts = git_describe_options()
            git_describe_options_init(&opts, UInt32(GIT_DESCRIBE_OPTIONS_VERSION))
            opts.describe_strategy = annotatedOnly ? GIT_DESCRIBE_DEFAULT.rawValue : GIT_DESCRIBE_TAGS.rawValue
            opts.max_candidates_tags = 10

            var result: OpaquePointer?
            defer { if result != nil { git_describe_result_free(result) } }

            let describeResult = git_describe_commit(&result, commit, &opts)
            guard describeResult == 0, let resultPtr = result else {
                return nil
            }

            var formatOpts = git_describe_format_options()
            git_describe_format_options_init(&formatOpts, UInt32(GIT_DESCRIBE_FORMAT_OPTIONS_VERSION))
            formatOpts.abbreviated_size = UInt32(min(max(abbrev, 2), 40))
            formatOpts.always_use_long_format = 0

            var buf = git_buf()
            defer { git_buf_dispose(&buf) }

            guard git_describe_format(&buf, resultPtr, &formatOpts) == 0 else {
                return nil
            }

            guard let ptr = buf.ptr else { return nil }
            let output = String(cString: ptr)
            return output.isEmpty ? nil : output
        }
    }
}
