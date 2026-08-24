import AgentToolKit
import CADDesignerPlugin

/// V2 implementation of the stable legacy `cad_connect_components` tool.
public struct ConnectComponentsV2Tool: SuperAgentTool {
    public static let toolName = "cad_connect_components"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Create a connection (rigid, hinge, or bolt) between two components in the assembly graph." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["fromComponentId": ["type": "string"], "toComponentId": ["type": "string"], "connectionType": ["type": "string", "enum": ["rigid", "hinge", "bolt"]], "fromFace": ["type": "string", "enum": ["end", "side", "top"]], "toFace": ["type": "string", "enum": ["end", "side", "top"]]], "required": ["fromComponentId", "toComponentId"]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Connect components" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let fromID = CADDesignerV2ToolSupport.string(arguments, "fromComponentId") else { return CADDesignerV2ToolSupport.missingParameter("fromComponentId") }
        guard let toID = CADDesignerV2ToolSupport.string(arguments, "toComponentId") else { return CADDesignerV2ToolSupport.missingParameter("toComponentId") }
        let type = ConnectionType(rawValue: CADDesignerV2ToolSupport.string(arguments, "connectionType") ?? "rigid") ?? .rigid
        let fromFace = ProfileFace(rawValue: CADDesignerV2ToolSupport.string(arguments, "fromFace") ?? "end") ?? .end
        let toFace = ProfileFace(rawValue: CADDesignerV2ToolSupport.string(arguments, "toFace") ?? "side") ?? .side
        let edge = ConnectionEdge(fromComponentID: fromID, toComponentID: toID, connectionType: type, fromFace: fromFace, toFace: toFace)
        do {
            let document = try await MainActor.run { try CADDocumentStore.shared.addConnection(edge) }
            return CADDesignerV2ToolSupport.localized(en: "Created connection.\nconnectionId: \(edge.id)\nfrom: \(fromID) → to: \(toID)\ntype: \(type.rawValue)\ntotalConnections: \(document.connections.count)", zh: "已创建连接。\n连接ID: \(edge.id)\n从: \(fromID) → 到: \(toID)\n类型: \(type.rawValue)\n总连接数: \(document.connections.count)")
        } catch { await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }; return CADDesignerV2ToolSupport.error(error) }
    }
}
