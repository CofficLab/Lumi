import AgentToolKit
import CADDesignerPlugin

/// V2 implementation of the stable legacy `cad_place_connector` tool.
public struct PlaceConnectorV2Tool: SuperAgentTool {
    public static let toolName = "cad_place_connector"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Place a connector (corner bracket, bolt, nut, end cap, or hinge) in the current CAD project." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["connectorId": ["type": "string", "description": "Connector spec id, e.g. 'connector-corner-40'."], "x": ["type": "number"], "y": ["type": "number"], "z": ["type": "number"], "rotationY": ["type": "number"]], "required": ["connectorId"]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Place connector \(CADDesignerV2ToolSupport.string(arguments, "connectorId") ?? "?")" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let connectorID = CADDesignerV2ToolSupport.string(arguments, "connectorId") else { return CADDesignerV2ToolSupport.missingParameter("connectorId") }
        guard ComponentLibrary.shared.connectorSpec(id: connectorID) != nil else {
            let available = ComponentLibrary.shared.connectors.map(\.id).joined(separator: ", ")
            return CADDesignerV2ToolSupport.localized(en: "Error: Unknown connector spec '\(connectorID)'. Available: \(available)", zh: "错误：未知连接件规格 '\(connectorID)'。可用：\(available)")
        }
        let instance = ConnectorInstance(connectorId: connectorID, transform: Transform3D(positionX: CADDesignerV2ToolSupport.double(arguments, "x", default: 0), positionY: CADDesignerV2ToolSupport.double(arguments, "y", default: 0), positionZ: CADDesignerV2ToolSupport.double(arguments, "z", default: 0), rotationY: CADDesignerV2ToolSupport.double(arguments, "rotationY", default: 0)))
        do {
            let component = try await MainActor.run { try CADDocumentStore.shared.addComponent(.connector(instance)) }
            return CADDesignerV2ToolSupport.localized(en: "Placed connector.\n\(CADDesignerV2ToolSupport.componentSummary(component))\nspec: \(connectorID)", zh: "已放置连接件。\n\(CADDesignerV2ToolSupport.componentSummary(component))\n规格: \(connectorID)")
        } catch { await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }; return CADDesignerV2ToolSupport.error(error) }
    }
}
