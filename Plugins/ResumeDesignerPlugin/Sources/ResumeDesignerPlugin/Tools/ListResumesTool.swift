import Foundation
import KernelLumi
import ResumeKit

public struct ListResumesTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_list",
        displayName: "List resumes",
        description: "List existing resume documents in one or both storage scopes."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties: [String: LumiJSONValue] = ResumeToolSupport.baseProperties()
        properties.removeValue(forKey: "resumeId")
        return ["type": "object", "properties": .object(properties)]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        var summaries: [String] = []
        for scope in Scope.allCases {
            do {
                let storagePath = try await ResumeToolSupport.storagePath(for: scope)
                let documents = try ResumeToolSupport.store.listResumes(storagePath: storagePath)
                summaries.append(contentsOf: documents.map { ResumeToolSupport.resumeSummary($0, scope: scope) })
            } catch {
                // 无存储路径的 scope 跳过而不是失败。
                continue
            }
        }
        guard !summaries.isEmpty else { return "No resumes found. Create one with resume_create." }
        return (["Found \(summaries.count) resume(s):"] + summaries).joined(separator: "\n")
    }
}
