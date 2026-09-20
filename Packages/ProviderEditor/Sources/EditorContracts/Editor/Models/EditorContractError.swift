import Foundation

/// 编辑器契约 V2 统一错误（见重构方案 §23）。
///
/// 用户可操作错误由 Host 以 Toast/Panel 展示；调试细节进入 Output/Log。
public enum EditorContractError: Error, Equatable, Sendable {
    /// 请求的能力不存在（无 Provider 或服务未注册）。
    case capabilityUnavailable(feature: String)

    /// 工作区未受信任，操作被拒绝。
    case workspaceNotTrusted

    /// 插件缺少所需权限。
    case permissionDenied(String)

    /// 文档不存在或已关闭。
    case documentNotFound(EditorDocumentID)

    /// 提交的 expected revision 与当前文档 revision 不一致。
    case revisionMismatch(documentID: EditorDocumentID, expected: UInt64, actual: UInt64)

    /// 目标文档只读。
    case readOnlyDocument(EditorDocumentID)

    /// Provider 执行失败（携带 provider id 与底层错误描述）。
    case providerFailed(providerID: String, reason: String)

    /// 请求被取消。
    case requestCancelled

    /// 请求超时。
    case requestTimedOut

    /// Workspace Edit 非法（重叠、越界或结构错误）。
    case invalidWorkspaceEdit(reason: String)

    /// 文件在编辑器外被修改，需要用户确认。
    case externalFileConflict(EditorDocumentID)

    /// 大文件模式下该能力被禁用。
    case largeFileRestriction(feature: String)

    /// Session 有未保存修改，需用户确认后才能按当前策略关闭。
    case closeRequiresConfirmation(EditorSessionID)
}

public extension EditorContractError {
    /// 是否为可安全重试的瞬时错误（取消不算失败）。
    var isTransient: Bool {
        switch self {
        case .requestCancelled, .requestTimedOut:
            return true
        default:
            return false
        }
    }

    /// 面向用户的简短描述（不含调试细节）。
    var userDescription: String {
        switch self {
        case .capabilityUnavailable(let feature):
            return "Capability unavailable: \(feature)"
        case .workspaceNotTrusted:
            return "This workspace is not trusted"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .documentNotFound:
            return "Document not found"
        case .revisionMismatch:
            return "The document changed while editing"
        case .readOnlyDocument:
            return "The document is read-only"
        case .providerFailed:
            return "The provider failed to complete the request"
        case .requestCancelled:
            return "The request was cancelled"
        case .requestTimedOut:
            return "The request timed out"
        case .invalidWorkspaceEdit:
            return "The edit could not be applied"
        case .externalFileConflict:
            return "The file changed on disk"
        case .largeFileRestriction(let feature):
            return "\(feature) is disabled for large files"
        case .closeRequiresConfirmation:
            return "The tab has unsaved changes"
        }
    }
}
