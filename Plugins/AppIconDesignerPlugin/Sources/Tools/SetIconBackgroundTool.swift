import Foundation
import LumiCoreKit

public struct SetIconBackgroundTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "set_icon_background",
        displayName: "Set Icon Background",
        description: "Set the background paint of the current icon document."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "color": ["type": "string", "description": "Background color, for example #111827 or #00000000."],
                "type": ["type": "string", "enum": ["color", "linearGradient", "radialGradient"], "description": "Background paint type."],
                "colors": ["type": "array", "items": ["type": "string"], "description": "Gradient colors."],
            ],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Set icon background"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
        let paint = makePaint(arguments: arguments)

        do {
            let document = try await MainActor.run {
                try IconDocumentStore.shared.updateSelectedDocument { document in
                    document.background = paint
                }
            }
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon background.
                documentId: \(document.id)
                """,
                zh: """
                已更新图标背景。
                文档ID: \(document.id)
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
