import AgentToolKit
import CADDesignerPlugin

/// V2 implementation of the stable legacy `cad_place_profile` tool.
public struct PlaceProfileV2Tool: SuperAgentTool {
    public static let toolName = "cad_place_profile"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Place an aluminum profile (extrusion) in the current CAD project." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [
            "profileId": ["type": "string", "description": "Profile spec id, e.g. 'profile-40x40-eu'."],
            "length": ["type": "number", "description": "Profile length in mm. Defaults to 500."],
            "x": ["type": "number", "description": "Position X in mm. Defaults to 0."],
            "y": ["type": "number", "description": "Position Y in mm. Defaults to 0."],
            "z": ["type": "number", "description": "Position Z in mm. Defaults to 0."],
            "rotationY": ["type": "number", "description": "Rotation around Y axis in degrees. Defaults to 0."],
        ], "required": ["profileId"]]
    }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Place profile \(CADDesignerV2ToolSupport.string(arguments, "profileId") ?? "?")" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let profileID = CADDesignerV2ToolSupport.string(arguments, "profileId") else { return CADDesignerV2ToolSupport.missingParameter("profileId") }
        guard ComponentLibrary.shared.profileSpec(id: profileID) != nil else {
            let available = ComponentLibrary.shared.profiles.map(\.id).joined(separator: ", ")
            return CADDesignerV2ToolSupport.localized(en: "Error: Unknown profile spec '\(profileID)'. Available: \(available)", zh: "错误：未知型材规格 '\(profileID)'。可用：\(available)")
        }
        let instance = ProfileInstance(profileId: profileID, length: CADDesignerV2ToolSupport.double(arguments, "length", default: 500), transform: Transform3D(positionX: CADDesignerV2ToolSupport.double(arguments, "x", default: 0), positionY: CADDesignerV2ToolSupport.double(arguments, "y", default: 0), positionZ: CADDesignerV2ToolSupport.double(arguments, "z", default: 0), rotationY: CADDesignerV2ToolSupport.double(arguments, "rotationY", default: 0)))
        do {
            let component = try await MainActor.run { try CADDocumentStore.shared.addComponent(.profile(instance)) }
            return CADDesignerV2ToolSupport.localized(en: "Placed profile.\n\(CADDesignerV2ToolSupport.componentSummary(component))\nspec: \(profileID)\nlength: \(Int(instance.length))mm", zh: "已放置型材。\n\(CADDesignerV2ToolSupport.componentSummary(component))\n规格: \(profileID)\n长度: \(Int(instance.length))mm")
        } catch { await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }; return CADDesignerV2ToolSupport.error(error) }
    }
}
