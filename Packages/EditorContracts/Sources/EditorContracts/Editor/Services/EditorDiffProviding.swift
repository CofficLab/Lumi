import Combine
import Foundation

// MARK: - Diff 能力（契约 V2，Phase 7 §15.5）

/// Diff 数据面：工作副本 diff 状态、任意两文本 diff 计算与逐块接受。
///
/// 同一基础设施服务 Diff 面板与 Agent 修改预览（§16）：
/// - `workingDiff`：活动文档缓冲 vs 磁盘基线；
/// - `computeDiff`：任意 old/new（Agent 提案、两文件比较）；
/// - `accept`：把 hunk 的变更落到当前缓冲（逐块接受/拒绝）。
@MainActor
public protocol EditorDiffProviding: AnyObject {
    /// 活动文档的工作副本 diff（无文档或与磁盘一致时为空 hunks）。
    var workingDiff: EditorV2DiffDocument? { get }

    /// 工作副本 diff 变更流；不以 failure 结束，新订阅者先收到当前值（§8.8）。
    var statePublisher: AnyPublisher<EditorV2DiffDocument?, Never> { get }

    /// 计算任意两段文本的行级 diff（宿主中立引擎，确定性输出）。
    func computeDiff(oldText: String, newText: String) -> [EditorV2DiffHunk]

    /// 接受 hunk：把变更应用到当前缓冲对应文档。
    ///
    /// hunk 按旧文本行号定位（`oldStart`/`removedContents`）；多个 hunk
    /// 由宿主按行号从高到低应用以保持定位稳定。失败抛契约错误。
    func accept(hunks: [EditorV2DiffHunk], in document: EditorDocumentID) async throws
}
