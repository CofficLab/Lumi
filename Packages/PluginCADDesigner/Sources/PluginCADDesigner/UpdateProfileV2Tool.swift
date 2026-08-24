import AgentToolKit
import CADDesignerPlugin

/// V2 implementation of the stable legacy `cad_update_profile` tool.
public struct UpdateProfileV2Tool: SuperAgentTool {
    public static let toolName = "cad_update_profile"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Update the length, position, or rotation of a component (profile or connector) by its component id." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["componentId": ["type": "string"], "length": ["type": "number"], "x": ["type": "number"], "y": ["type": "number"], "z": ["type": "number"], "rotationY": ["type": "number"]], "required": ["componentId"]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Update component \(CADDesignerV2ToolSupport.string(arguments, "componentId") ?? "?")" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let componentID = CADDesignerV2ToolSupport.string(arguments, "componentId") else { return CADDesignerV2ToolSupport.missingParameter("componentId") }
        do {
            let document = try await MainActor.run { try CADDocumentStore.shared.updateComponent(id: componentID) { component in
                var transform = component.transform
                if let x = CADDesignerV2ToolSupport.double(arguments, "x") { transform.positionX = x }
                if let y = CADDesignerV2ToolSupport.double(arguments, "y") { transform.positionY = y }
                if let z = CADDesignerV2ToolSupport.double(arguments, "z") { transform.positionZ = z }
                if let rotationY = CADDesignerV2ToolSupport.double(arguments, "rotationY") { transform.rotationY = rotationY }
                component.transform = transform
                if let length = CADDesignerV2ToolSupport.double(arguments, "length"), case .profile(var profile) = component { profile.length = length; component = .profile(profile) }
            } }
            return CADDesignerV2ToolSupport.localized(en: "Updated component.\nprojectId: \(document.id)\ncomponentId: \(componentID)", zh: "已更新组件。\n项目ID: \(document.id)\n组件ID: \(componentID)")
        } catch { await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }; return CADDesignerV2ToolSupport.error(error) }
    }
}
