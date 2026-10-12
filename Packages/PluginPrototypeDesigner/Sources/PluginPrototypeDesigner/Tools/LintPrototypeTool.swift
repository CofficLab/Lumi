import Foundation
import KitAgentTool
import KitPrototype

/// 校验原型项目中每一屏的 HTML 与资源引用。
public struct LintPrototypeTool: SuperAgentTool {
    public let name = "prototype_lint"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Validate every screen's HTML, asset references, and navigation targets in a prototype project. Reports PASS/FAIL per screen with issue codes."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(), "required": ["projectId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Lint prototype", zh: "校验原型项目")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let storagePath = try await PrototypeToolSupport.storagePath()
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let project = try PrototypeToolSupport.store.readProject(
            storagePath: storagePath,
            projectSlug: projectID
        )
        guard !project.screens.isEmpty else { return "Lint failed: project has no screens." }

        let reports = try PrototypeToolSupport.store.lintProject(
            storagePath: storagePath,
            projectSlug: projectID
        )
        var lines: [String] = []
        var errorCount = 0
        for screen in project.sortedScreens {
            guard let report = reports[screen.id] else { continue }
            errorCount += report.errors.count
            let details = report.issues
                .map { "\($0.severity.rawValue):\($0.code) \($0.message)" }
                .joined(separator: " | ")
            lines.append("screen=\(screen.id) \(report.isValid ? "valid" : "invalid") \(details)")
        }
        let header = "Prototype lint: \(errorCount == 0 ? "PASS" : "FAIL") errors=\(errorCount)"
        return ([header] + lines + [PrototypeToolSupport.flowSummary(project)]).joined(separator: "\n")
    }
}
