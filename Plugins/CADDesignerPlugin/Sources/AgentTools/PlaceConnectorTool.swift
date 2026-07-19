import Foundation
import LumiKernel

/// 放置连接件到当前项目。
public struct PlaceConnectorTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_place_connector",
        displayName: "Place Connector",
        description: "Place a connector (corner bracket, bolt, nut, end cap, or hinge) in the current CAD project."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "connectorId": ["type": "string", "description": "Connector spec id, e.g. 'connector-corner-40'."],
                "x": ["type": "number", "description": "Position X in mm. Defaults to 0."],
                "y": ["type": "number", "description": "Position Y in mm. Defaults to 0."],
                "z": ["type": "number", "description": "Position Z in mm. Defaults to 0."],
                "rotationY": ["type": "number", "description": "Rotation around Y axis in degrees. Defaults to 0."],
            ],
            "required": ["connectorId"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Place connector \(CADToolSupport.string(arguments, "connectorId") ?? "?")"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        guard let connectorId = CADToolSupport.string(arguments, "connectorId") else {
            return CADToolSupport.missingParameter("connectorId", language: language)
        }

        guard ComponentLibrary.shared.connectorSpec(id: connectorId) != nil else {
            return CADToolSupport.localized(
                language,
                en: "Error: Unknown connector spec '\(connectorId)'. Available: \(ComponentLibrary.shared.connectors.map(\.id).joined(separator: ", "))",
                zh: "错误：未知连接件规格 '\(connectorId)'。可用：\(ComponentLibrary.shared.connectors.map(\.id).joined(separator: ", "))"
            )
        }

        let x = CADToolSupport.double(arguments, "x", default: 0)
        let y = CADToolSupport.double(arguments, "y", default: 0)
        let z = CADToolSupport.double(arguments, "z", default: 0)
        let rotY = CADToolSupport.double(arguments, "rotationY", default: 0)

        let instance = ConnectorInstance(
            connectorId: connectorId,
            transform: Transform3D(positionX: x, positionY: y, positionZ: z, rotationY: rotY)
        )

        do {
            let component = try await MainActor.run {
                try CADDocumentStore.shared.addComponent(.connector(instance))
            }
            switch language {
            case .chinese:
                return """
                已放置连接件。
                \(CADToolSupport.componentSummary(component, library: .shared, language: language))
                规格: \(connectorId)
                """
            case .english:
                return """
                Placed connector.
                \(CADToolSupport.componentSummary(component, library: .shared, language: language))
                spec: \(connectorId)
                """
            }
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADToolSupport.error(error, language: language)
        }
    }
}
