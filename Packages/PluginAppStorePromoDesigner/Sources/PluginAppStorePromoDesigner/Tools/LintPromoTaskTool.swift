import AgentToolKit
import AppStorePromoKit
import Foundation

/// 校验促销图任务中的每张 HTML 图片与所有本地资源引用。
public struct LintPromoTaskTool: SuperAgentTool {
    public let name = "app_store_promo_lint_task"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Validate every HTML image and all local asset references in a promotional task."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PromoToolSupport.baseProperties(), "required": ["taskId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Lint promo task", zh: "校验促销图任务")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let task = try PromoToolSupport.store.readTask(storagePath: storagePath, taskSlug: taskID)
        guard !task.images.isEmpty else { return "Lint failed: task has no images." }
        var lines: [String] = []
        var errors = 0
        for image in task.images.sorted(by: { $0.order < $1.order }) {
            for localeIdentifier in image.localeIdentifiers {
                let report = try PromoToolSupport.store.lintImage(
                    storagePath: storagePath,
                    taskSlug: taskID,
                    imageSlug: image.id,
                    localeIdentifier: localeIdentifier
                )
                errors += report.errors.count
                let details = report.issues.map { "\($0.severity.rawValue):\($0.code) \($0.message)" }.joined(separator: " | ")
                lines.append("image=\(image.id) locale=\(localeIdentifier) \(report.isValid ? "valid" : "invalid") \(details)")
            }
        }
        return (["Promo task lint (scope=\(scope.rawValue)): \(errors == 0 ? "PASS" : "FAIL") errors=\(errors)"] + lines).joined(separator: "\n")
    }
}
