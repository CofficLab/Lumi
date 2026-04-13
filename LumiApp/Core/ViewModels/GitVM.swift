import Foundation
import MagicKit
import SwiftUI

/// Git 数据 ViewModel
///
/// 管理 Git 相关的全局状态，包括当前选中的 commit ID、未推送 commit 等。
/// 作为 Git 数据的中心化存储，供多个插件和视图共享。
@MainActor
final class GitVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔀"
    nonisolated static let verbose: Bool = false
    // MARK: - Commit Selection

    /// 当前选中的 commit hash
    ///
    /// 由 GitCommitHistoryPlugin 的侧边栏在用户点击某个 commit 时设置，
    /// GitCommitDetailPlugin 会监听此属性变化来显示对应的 commit 详情。
    @Published private(set) var selectedCommitHash: String?

    // MARK: - File Selection

    /// 当前在 commit detail 中选中的变更文件路径
    ///
    /// 由 GitCommitDetailView 中的文件列表设置，
    /// 用于在 diff 视图中显示对应文件的差异。
    @Published private(set) var selectedCommitFile: String?

    // MARK: - Unpushed Commits

    /// 未推送到远程的 commit 哈希集合（用于快速查询某个 commit 是否未推送）
    @Published private(set) var unpushedCommitHashes: Set<String> = []

    /// 未推送的 commit 数量
    @Published private(set) var unpushedCommitsCount: Int = 0

    // MARK: - Init

    init() {}

    // MARK: - Setter

    /// 设置当前选中的 commit hash
    /// - Parameter hash: commit hash，传 nil 表示取消选中
    func selectCommit(hash: String?) {
        guard hash != selectedCommitHash else { return }

        selectedCommitHash = hash

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📌 选中 commit: \(hash?.prefix(7) ?? "nil")")
        }
    }

    /// 清除当前选中的 commit
    func clearSelection() {
        guard selectedCommitHash != nil else { return }

        selectedCommitHash = nil

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📌 已清除 commit 选择")
        }
    }

    /// 设置当前选中的变更文件
    /// - Parameter file: 文件相对路径，传 nil 表示取消选中
    func selectCommitFile(_ file: String?) {
        selectedCommitFile = file

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📄 选中文件: \(file ?? "nil")")
        }
    }

    // MARK: - Unpushed Commits Management

    /// 更新未推送的 commit 哈希集合（供 GitCommitHistorySidebarView 调用）
    /// - Parameter hashes: 未推送的 commit 哈希数组
    func updateUnpushedCommitHashes(_ hashes: [String]) {
        let newSet = Set(hashes)
        guard newSet != unpushedCommitHashes else { return }

        unpushedCommitHashes = newSet
        unpushedCommitsCount = hashes.count

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📤 未推送 commit 数量: \(hashes.count)")
        }
    }

    /// 清除未推送 commit 状态（项目切换时调用）
    func clearUnpushedCommits() {
        guard !unpushedCommitHashes.isEmpty else { return }

        unpushedCommitHashes = []
        unpushedCommitsCount = 0
    }

    /// 检查指定 commit 是否未推送到远程
    /// - Parameter commitHash: commit 哈希值
    /// - Returns: 是否未推送
    func isCommitUnpushed(_ commitHash: String) -> Bool {
        return unpushedCommitHashes.contains(commitHash)
    }
}
