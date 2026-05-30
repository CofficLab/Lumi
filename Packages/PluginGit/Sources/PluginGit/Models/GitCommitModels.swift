import Foundation

// MARK: - Git Commit Log

public struct GitCommitLog: Codable {
    public let hash: String
    public let author: String
    public let email: String
    public let date: String
    public let message: String
}

// MARK: - Git Commit Detail

/// Git Commit 详情模型
///
/// 包含 commit 的完整信息，包括 body、变更统计和文件列表。
public struct GitCommitDetail: Codable {
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
