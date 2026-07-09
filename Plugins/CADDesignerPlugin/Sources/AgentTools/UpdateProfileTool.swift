import Foundation
import LumiCoreKit

/// 修改现有型材或组件的长度/位置/旋转。
public struct UpdateProfileTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_update_profile",
        displayName: "Update Component",
        description: "Update the length, position, or rotation of a component (profile or connector) by its component id."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "componentId": ["type": "string", "description": "The component id to update."],
                "length": ["type": "number", "description": "New length in mm (profiles only)."],
                "x": ["type": "number", "description": "New position X in mm."],
                "y": ["type": "number", "description": "New position Y in mm."],
                "z": ["type": "number", "description": "New position Z in mm."],
                "rotationY": ["type": "number", "description": "New rotation around Y axis in degrees."],
            ],
            "required": ["componentId"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Update component \(CADToolSupport.string(arguments, "componentId") ?? "?")"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        guard let componentId = CADToolSupport.string(arguments, "componentId") else {
            return CADToolSupport.missingParameter("componentId", language: language)
        }

        let length = arguments.double("length")
        let x = arguments.double("x")
        let y = arguments.double("y")
        let z = arguments.double("z")
        let rotY = arguments.double("rotationY")

        do {
            let document = try await MainActor.run {
                try CADDocumentStore.shared.updateComponent(id: componentId) { component in
                    // 更新变换（保留未指定字段的原值）
                    var t = component.transform
                    if let x { t.positionX = x }
                    if let y { t.positionY = y }
                    if let z { t.positionZ = z }
                    if let rotY { t.rotationY = rotY }
                    component.transform = t

                    // 更新长度（仅型材）
                    if let length, case .profile(var instance) = component {
                        instance.length = length
                        component = .profile(instance)
                    }
                }
            }
            switch language {
            case .chinese:
                return """
                已更新组件。
                项目ID: \(document.id)
                组件ID: \(componentId)
                """
            case .english:
                return """
                Updated component.
                projectId: \(document.id)
                componentId: \(componentId)
                """
            }
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADToolSupport.error(error, language: language)
        }
    }
}
