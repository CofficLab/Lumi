import Foundation
import KernelLumi
import ResumeKit

/// 共享给所有简历工具的辅助逻辑：存储、参数校验、通知与摘要。
/// 简历文档仅存储在应用数据目录（app 作用域），不支持项目内存储。
enum ResumeToolSupport {
    static let store = ResumeDocumentStore()

    /// 当前 app 存储路径（应用数据目录）。无路径时抛 invalidStoragePath。
    static func storagePath() async throws -> String {
        try await MainActor.run {
            let path = WorkspaceStore.shared.appStoragePath
            guard !path.isEmpty else { throw ResumeStoreError.invalidStoragePath }
            return path
        }
    }

    static func required(_ key: String, _ arguments: [String: LumiJSONValue]) throws -> String {
        guard let value = arguments.string(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(resumeID: String? = nil) async {
        await MainActor.run { WorkspaceStore.shared.reload(selectResume: resumeID) }
    }

    static func resumeSummary(_ document: ResumeDocument) -> String {
        "resumeId=\(document.id) title=\(document.title) paper=\(document.paper.rawValue) template=\(document.template.rawValue) updatedAt=\(document.updatedAt.timeIntervalSince1970)"
    }

    static func baseProperties() -> [String: LumiJSONValue] {
        [
            "resumeId": ["type": "string", "description": "Resume slug."],
        ]
    }

    enum ToolArgumentError: LocalizedError {
        case missing(String)
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .missing(let key): "Missing required argument: \(key)"
            case .invalid(let key): "Invalid argument: \(key)"
            }
        }
    }
}
