import Foundation

// MARK: - Git Commit Log

struct GitCommitLog: Codable {
    let hash: String
    let author: String
    let email: String
    let date: String
    let message: String
}

// MARK: - Git Commit Detail

/// Git Commit 详情模型
///
/// 包含 commit 的完整信息，包括 body、变更统计和文件列表。
struct GitCommitDetail: Codable {
    /// 完整的 commit hash
    let hash: String
    /// 作者名称
    let author: String
    /// 作者邮箱
    let email: String
    /// 提交日期（ISO 格式）
    let date: String
    /// 提交消息（subject，第一行）
    let message: String
    /// 提交正文（subject 之后的内容）
    let body: String
    /// 变更统计
    let stats: GitDiffStats?
    /// 变更文件列表
    let changedFiles: [String]
}
