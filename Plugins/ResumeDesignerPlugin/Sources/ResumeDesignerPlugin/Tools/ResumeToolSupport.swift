import Foundation
import KernelLumi
import ResumeKit

/// 共享给所有简历工具的辅助逻辑：存储、scope 解析、参数校验、通知与摘要。
enum ResumeToolSupport {
    static let store = ResumeDocumentStore()

    /// 当前已打开项目的路径（来自工具执行上下文，回退到 Runtime 缓存）。
    static func currentProjectPath(kernel: KernelLumi) async -> String? {
        if let fromContext = kernel.currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromContext.isEmpty {
            return fromContext
        }
        return await MainActor.run { Runtime.currentProjectPath }
    }

    /// 解析工具入参中的 scope：未指定时按是否有打开项目自动选择 project / app。
    static func resolveScope(_ arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> Scope {
        if let raw = arguments.string("scope")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !raw.isEmpty {
            guard let scope = Scope(rawValue: raw) else {
                throw ToolArgumentError.invalid("scope")
            }
            return scope
        }
        let hasProject = await (currentProjectPath(kernel: kernel) != nil)
        return await MainActor.run { Runtime.defaultScope(hasOpenProject: hasProject) }
    }

    /// 当前 scope 的存储路径。无路径时抛 invalidStoragePath。
    static func storagePath(for scope: Scope) async throws -> String {
        try await MainActor.run {
            let path: String
            switch scope {
            case .project: path = WorkspaceStore.shared.projectStoragePath
            case .app: path = WorkspaceStore.shared.appStoragePath
            }
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

    static func notify(scope: Scope, resumeID: String? = nil) async {
        await MainActor.run { WorkspaceStore.shared.reload(scope: scope, selectResume: resumeID) }
    }

    static func resumeSummary(_ document: ResumeDocument, scope: Scope) -> String {
        "scope=\(scope.rawValue) resumeId=\(document.id) title=\(document.title) paper=\(document.paper.rawValue) template=\(document.template.rawValue) updatedAt=\(document.updatedAt.timeIntervalSince1970)"
    }

    static func baseProperties() -> [String: LumiJSONValue] {
        [
            "scope": [
                "type": "string",
                "enum": .array(Scope.allCases.map { .string($0.rawValue) }),
                "description": "Storage scope: 'project' (current project .lumi folder) or 'app' (application data directory). Defaults to 'project' when a project is open, else 'app'.",
            ],
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
