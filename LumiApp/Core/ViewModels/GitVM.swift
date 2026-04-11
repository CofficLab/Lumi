import Foundation
import MagicKit
import SwiftUI

/// Git 数据 ViewModel
///
/// 管理 Git 相关的全局状态，包括当前选中的 commit ID 等。
/// 作为 Git 数据的中心化存储，供多个插件和视图共享。
@MainActor
final class GitVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔀"
    nonisolated static let verbose = false

    // MARK: - Commit Selection

    /// 当前选中的 commit hash
    ///
    /// 由 GitCommitHistoryPlugin 的侧边栏在用户点击某个 commit 时设置，
    /// GitCommitDetailPlugin 会监听此属性变化来显示对应的 commit 详情。
    @Published private(set) var selectedCommitHash: String?

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
}
