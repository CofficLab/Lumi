import Foundation
import ProviderGit

// MARK: - Git Commit Detail

/// Git Commit 详情模型
///
/// 包含 commit 的完整信息，包括 body、变更统计和文件列表。
/// 这是插件内部的富模型：契约层（`ProviderGit`）只暴露 ``GitCommitLog``，
/// 详情里的 `stats` 依赖本插件的 diff 模型，因此不下沉。
public struct GitCommitDetail: Codable, Sendable {
    /// 完整的 commit hash
    public let hash: String
    /// 作者名称
    public let author: String
    /// 作者邮箱
    public let email: String
    /// 提交日期（ISO 格式）
    public let date: String
    /// 提交消息（subject，第一行）
    public let message: String
    /// 提交正文（subject 之后的内容）
    public let body: String
    /// 变更统计
    public let stats: GitDiffStats?
    /// 变更文件列表
    public let changedFiles: [String]
}
