import AppStorePromoKit
import Foundation
import LumiKernel

public struct LintPromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_lint_task",
        displayName: "Lint promo task",
        description: "Validate every HTML image and all local asset references in a promotional task."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["taskId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let task = try PromoToolSupport.store.readTask(storagePath: storagePath, taskSlug: taskID)
        guard !task.images.isEmpty else { return "Lint failed: task has no images." }
        var lines: [String] = []
        var errors = 0
        for image in task.images.sorted(by: { $0.order < $1.order }) {
            let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: taskID, imageSlug: image.id)
            errors += report.errors.count
            let details = report.issues.map { "\($0.severity.rawValue):\($0.code) \($0.message)" }.joined(separator: " | ")
            lines.append("image=\(image.id) \(report.isValid ? "valid" : "invalid") \(details)")
        }
        return (["Promo task lint (scope=\(scope.rawValue)): \(errors == 0 ? "PASS" : "FAIL") errors=\(errors)"] + lines).joined(separator: "\n")
    }
}