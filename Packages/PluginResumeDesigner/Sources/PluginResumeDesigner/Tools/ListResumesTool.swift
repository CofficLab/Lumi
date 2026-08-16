import AgentToolKit
import Foundation
import ResumeKit

public struct ListResumesTool: SuperAgentTool {
    public let name = "resume_list"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List existing resume documents in the application data directory."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [String: Any]()]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List resumes"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let storagePath = try await ResumeToolSupport.storagePath()
        let documents = try ResumeToolSupport.store.listResumes(storagePath: storagePath)
        let summaries = documents.map { ResumeToolSupport.resumeSummary($0) }
        guard !summaries.isEmpty else { return "No resumes found. Create one with resume_create." }
        return (["Found \(summaries.count) resume(s):"] + summaries).joined(separator: "\n")
    }
}
