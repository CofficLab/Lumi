import Foundation
import KernelLumi

public struct SetIconBackgroundTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "set_icon_background",
        displayName: "Set Icon Background",
        description: "Set the background paint of the current icon document."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = IconToolSupport.baseProperties()
        properties["color"] = ["type": "string", "description": "Background color, for example #111827 or #00000000."]
        properties["type"] = ["type": "string", "enum": ["color", "linearGradient", "radialGradient"], "description": "Background paint type."]
        properties["colors"] = ["type": "array", "items": ["type": "string"], "description": "Gradient colors."]
        return ["type": "object", "properties": .object(properties)]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Set icon background"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = IconToolSupport.language(kernel)
        let paint = makePaint(arguments: arguments)

        do {
            let (document, scope) = try await IconToolSupport.resolveDocument(arguments, kernel: kernel)
            let updated = try await MainActor.run {
                try IconDocumentStore.shared.updateDocument(id: document.id, scope: scope) { document in
                    document.background = paint
                }
            }
            await IconToolSupport.notify(scope: scope, documentId: document.id)
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon background.
                scope=\(scope.rawValue)
                documentId: \(updated.id)
                """,
                zh: """
                已更新图标背景。
                作用域: \(scope.rawValue)
                文档ID: \(updated.id)
                """
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func makePaint(arguments: [String: LumiJSONValue]) -> IconPaint {
        let type = IconToolSupport.string(arguments, "type") ?? "color"
        let colors = (arguments["colors"]?.anyValue as? [String]) ?? []
        switch type {
        case "linearGradient":
            return .linearGradient(
                colors: colors.isEmpty ? ["#111827", "#2563eb"] : colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "radialGradient":
            return .radialGradient(
                colors: colors.isEmpty ? ["#38bdf8", "#111827"] : colors,
                center: .center,
                startRadius: 0,
                endRadius: 720
            )
        default:
            return .color(IconToolSupport.string(arguments, "color") ?? "#00000000")
        }
    }
}
