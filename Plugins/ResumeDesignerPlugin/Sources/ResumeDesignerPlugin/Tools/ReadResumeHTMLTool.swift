import Foundation
import KernelLumi
import ResumeKit

public struct ReadResumeHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_read_html",
        displayName: "Read resume HTML",
        description: "Read the complete HTML source of one resume."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(ResumeToolSupport.baseProperties()), "required": ["resumeId"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await ResumeToolSupport.resolveScope(arguments, kernel: kernel)
        let resume = try ResumeToolSupport.store.readResume(
            storagePath: try await ResumeToolSupport.storagePath(for: scope),
            slug: try ResumeToolSupport.required("resumeId", arguments)
        )
        return "scope=\(scope.rawValue) resumeId=\(resume.document.id)\n\(resume.html)"
    }
}
