import Combine
import Foundation

/// 文档能力（契约 V2，见重构方案 §8.2）。
///
/// 打开、快照、保存、回滚与 revision-aware 编辑事务。
/// 完整文本只通过 `snapshot(documentID:)` 按需获取；
/// 常规状态订阅使用 `EditorDocumentState`（不含文本）。
@MainActor
public protocol EditorDocumentProviding: AnyObject {
    /// 当前活动文档摘要。
    var activeDocument: EditorDocumentSummary? { get }

    /// 文档集合状态流（CurrentValue 语义）。
    var statePublisher: AnyPublisher<EditorDocumentState, Never> { get }

    /// 获取完整文档快照（含文本与 revision）。
    ///
    /// - Throws: `EditorContractError.documentNotFound` 文档未打开。
    func snapshot(documentID: EditorDocumentID) async throws -> EditorDocumentSnapshot

    /// 打开文档，返回对应 Session。
    ///
    /// - Throws: `EditorContractError.capabilityUnavailable` 无法读取该 URI；
    ///   `EditorContractError.externalFileConflict` 打开过程中文件被外部修改。
    func open(_ request: EditorOpenRequest) async throws -> EditorSessionID

    /// 保存单个文档。
    ///
    /// - Throws: `EditorContractError.readOnlyDocument`、`EditorContractError.documentNotFound`。
    func save(documentID: EditorDocumentID, reason: EditorSaveReason) async throws

    /// 保存全部脏文档。
    func saveAll(reason: EditorSaveReason) async throws

    /// 放弃未保存修改，恢复到磁盘内容。
    func revert(documentID: EditorDocumentID) async throws

    /// 重新加载磁盘内容（外部修改后）。
    func reload(documentID: EditorDocumentID) async throws

    /// 大文件模式下按需加载完整内容（解除懒加载限制）。
    func loadFullDocument(documentID: EditorDocumentID) async throws

    /// 应用跨文档编辑事务。
    ///
    /// Host 必须：验证编辑不重叠、校验 `expectedRevisions`、应用前可生成预览摘要，
    /// 文件操作经 Workspace 权限校验（§7.4）。
    /// - Throws: `EditorContractError.invalidWorkspaceEdit`、
    ///   `EditorContractError.revisionMismatch`、`EditorContractError.readOnlyDocument`。
    func apply(
        _ edit: EditorWorkspaceEdit,
        expectedRevisions: [EditorDocumentID: UInt64],
        options: EditorEditOptions
    ) async throws -> EditorWorkspaceEditResult
}
