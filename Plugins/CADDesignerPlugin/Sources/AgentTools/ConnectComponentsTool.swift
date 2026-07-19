import Foundation
import LumiKernel

/// 在两个组件之间建立装配连接关系。
public struct ConnectComponentsTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_connect_components",
        displayName: "Connect Components",
        description: "Create a connection (rigid, hinge, or bolt) between two components in the assembly graph."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "fromComponentId": ["type": "string", "description": "Source component id."],
                "toComponentId": ["type": "string", "description": "Target component id."],
                "connectionType": [
                    "type": "string",
                    "enum": ["rigid", "hinge", "bolt"],
                    "description": "Connection type. Defaults to 'rigid'.",
                ],
                "fromFace": [
                    "type": "string",
                    "enum": ["end", "side", "top"],
                    "description": "Source face. Defaults to 'end'.",
                ],
                "toFace": [
                    "type": "string",
                    "enum": ["end", "side", "top"],
                    "description": "Target face. Defaults to 'side'.",
                ],
            ],
            "required": ["fromComponentId", "toComponentId"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Connect components"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        guard let fromId = CADToolSupport.string(arguments, "fromComponentId") else {
            return CADToolSupport.missingParameter("fromComponentId", language: language)
        }
        guard let toId = CADToolSupport.string(arguments, "toComponentId") else {
            return CADToolSupport.missingParameter("toComponentId", language: language)
        }

        let connectionType = ConnectionType(rawValue: CADToolSupport.string(arguments, "connectionType") ?? "rigid") ?? .rigid
        let fromFace = ProfileFace(rawValue: CADToolSupport.string(arguments, "fromFace") ?? "end") ?? .end
        let toFace = ProfileFace(rawValue: CADToolSupport.string(arguments, "toFace") ?? "side") ?? .side

        let edge = ConnectionEdge(
            fromComponentID: fromId,
            toComponentID: toId,
            connectionType: connectionType,
            fromFace: fromFace,
            toFace: toFace
        )

        do {
            let document = try await MainActor.run {
                try CADDocumentStore.shared.addConnection(edge)
            }
            switch language {
            case .chinese:
                return """
                已创建连接。
                连接ID: \(edge.id)
                从: \(fromId) → 到: \(toId)
                类型: \(connectionType.rawValue)
                总连接数: \(document.connections.count)
                """
            case .english:
                return """
                Created connection.
                connectionId: \(edge.id)
                from: \(fromId) → to: \(toId)
                type: \(connectionType.rawValue)
                totalConnections: \(document.connections.count)
                """
            }
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADToolSupport.error(error, language: language)
        }
    }
}
