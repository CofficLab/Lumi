import Foundation
import KernelLumi
import ResumeKit

public struct ListResumesTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_list",
        displayName: "List resumes",
        description: "List existing resume documents in the application data directory."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object([:])]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let storagePath = try await ResumeToolSupport.storagePath()
        let documents = try ResumeToolSupport.store.listResumes(storagePath: storagePath)
        let summaries = documents.map { ResumeToolSupport.resumeSummary($0) }
        guard !summaries.isEmpty else { return "No resumes found. Create one with resume_create." }
        return (["Found \(summaries.count) resume(s):"] + summaries).joined(separator: "\n")
    }
}
