import Foundation
import LumiCoreKit

/// 放置型材到当前项目。
public struct PlaceProfileTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_place_profile",
        displayName: "Place Profile",
        description: "Place an aluminum profile (extrusion) in the current CAD project. Requires a profile spec id from the catalog (e.g. profile-40x40-eu)."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "profileId": ["type": "string", "description": "Profile spec id, e.g. 'profile-40x40-eu'."],
                "length": ["type": "number", "description": "Profile length in mm. Defaults to 500."],
                "x": ["type": "number", "description": "Position X in mm. Defaults to 0."],
                "y": ["type": "number", "description": "Position Y in mm. Defaults to 0."],
                "z": ["type": "number", "description": "Position Z in mm. Defaults to 0."],
                "rotationY": ["type": "number", "description": "Rotation around Y axis in degrees. Defaults to 0."],
            ],
            "required": ["profileId"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Place profile \(CADToolSupport.string(arguments, "profileId") ?? "?")"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        guard let profileId = CADToolSupport.string(arguments, "profileId") else {
            return CADToolSupport.missingParameter("profileId", language: language)
        }

        // 校验型材规格存在
        guard ComponentLibrary.shared.profileSpec(id: profileId) != nil else {
            return CADToolSupport.localized(
                language,
                en: "Error: Unknown profile spec '\(profileId)'. Available: \(ComponentLibrary.shared.profiles.map(\.id).joined(separator: ", "))",
                zh: "错误：未知型材规格 '\(profileId)'。可用：\(ComponentLibrary.shared.profiles.map(\.id).joined(separator: ", "))"
            )
        }

        let length = CADToolSupport.double(arguments, "length", default: 500)
        let x = CADToolSupport.double(arguments, "x", default: 0)
        let y = CADToolSupport.double(arguments, "y", default: 0)
        let z = CADToolSupport.double(arguments, "z", default: 0)
        let rotY = CADToolSupport.double(arguments, "rotationY", default: 0)

        let instance = ProfileInstance(
            profileId: profileId,
            length: length,
            transform: Transform3D(positionX: x, positionY: y, positionZ: z, rotationY: rotY)
        )

        do {
            let component = try await MainActor.run {
                try CADDocumentStore.shared.addComponent(.profile(instance))
            }
            switch language {
            case .chinese:
                return """
                已放置型材。
                \(CADToolSupport.componentSummary(component, library: .shared, language: language))
                规格: \(profileId)
                长度: \(Int(length))mm
                """
            case .english:
                return """
                Placed profile.
                \(CADToolSupport.componentSummary(component, library: .shared, language: language))
                spec: \(profileId)
                length: \(Int(length))mm
                """
            }
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADToolSupport.error(error, language: language)
        }
    }
}
