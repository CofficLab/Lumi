import AgentToolKit
import CADDesignerPlugin

/// V2 implementation of the stable legacy `cad_build_frame` tool.
public struct BuildFrameV2Tool: SuperAgentTool {
    public static let toolName = "cad_build_frame"
    public let name = Self.toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Build a rectangular aluminum profile frame from dimensions (width × depth × height in mm). Generates 4 vertical posts, 8 horizontal beams, and corner brackets."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "width": ["type": "number", "description": "Frame width (X axis) in mm."],
                "depth": ["type": "number", "description": "Frame depth (Z axis) in mm."],
                "height": ["type": "number", "description": "Frame height (Y axis) in mm."],
                "series": ["type": "string", "enum": ["20", "30", "40"], "description": "Profile series. Defaults to '40' (heavy duty)."],
                "profileId": ["type": "string", "description": "Override profile spec id (e.g. 'profile-40x40-eu'). Defaults to a square profile of the chosen series."],
            ],
            "required": ["width", "depth", "height"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let width = CADDesignerV2ToolSupport.double(arguments, "width").map(Int.init) ?? 0
        let height = CADDesignerV2ToolSupport.double(arguments, "height").map(Int.init) ?? 0
        return "Build frame \(width)×\(height)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let width = CADDesignerV2ToolSupport.double(arguments, "width") else {
            return CADDesignerV2ToolSupport.missingParameter("width")
        }
        guard let depth = CADDesignerV2ToolSupport.double(arguments, "depth") else {
            return CADDesignerV2ToolSupport.missingParameter("depth")
        }
        guard let height = CADDesignerV2ToolSupport.double(arguments, "height") else {
            return CADDesignerV2ToolSupport.missingParameter("height")
        }

        let series = ProfileSeries(rawValue: CADDesignerV2ToolSupport.string(arguments, "series") ?? "40") ?? .series40
        let profileID: String
        if let override = CADDesignerV2ToolSupport.string(arguments, "profileId"),
           ComponentLibrary.shared.profileSpec(id: override) != nil {
            profileID = override
        } else if let square = ComponentLibrary.shared.profiles.first(where: { $0.series == series && $0.width == $0.height }) {
            profileID = square.id
        } else {
            return CADDesignerV2ToolSupport.localized(
                en: "Error: No square profile found for series \(series.rawValue).",
                zh: "错误：\(series.rawValue) 系列未找到正方形型材。"
            )
        }
        guard let spec = ComponentLibrary.shared.profileSpec(id: profileID) else {
            return CADDesignerV2ToolSupport.localized(en: "Error: Unknown profile spec '\(profileID)'.", zh: "错误：未知型材规格 '\(profileID)'。")
        }

        let connectorID = ComponentLibrary.shared.connectors.first { $0.series == series && $0.kind == .cornerBracket }?.id
        let halfWidth = width / 2
        let halfDepth = depth / 2
        let offset = spec.width / 2
        let postCorners: [(Double, Double)] = [
            (-halfWidth + offset, -halfDepth + offset), (halfWidth - offset, -halfDepth + offset),
            (-halfWidth + offset, halfDepth - offset), (halfWidth - offset, halfDepth - offset),
        ]
        var components: [CADComponent] = []
        for (x, z) in postCorners {
            components.append(.profile(ProfileInstance(
                profileId: profileID, length: height,
                transform: Transform3D(positionX: x, positionY: height / 2, positionZ: z, rotationX: 0, rotationY: 0, rotationZ: 90)
            )))
        }

        let beamXLength = max(width - 2 * spec.width, 10)
        let beamZLength = max(depth - 2 * spec.width, 10)
        for y in [spec.width / 2, height - spec.width / 2] {
            for z in [-(halfDepth - offset), halfDepth - offset] {
                components.append(.profile(ProfileInstance(profileId: profileID, length: beamXLength, transform: Transform3D(positionX: 0, positionY: y, positionZ: z, rotationY: 0))))
            }
            for x in [-(halfWidth - offset), halfWidth - offset] {
                components.append(.profile(ProfileInstance(profileId: profileID, length: beamZLength, transform: Transform3D(positionX: x, positionY: y, positionZ: 0, rotationY: 90))))
            }
        }
        if let connectorID {
            for (x, z) in postCorners {
                for y in [spec.width / 2, height - spec.width / 2] {
                    components.append(.connector(ConnectorInstance(connectorId: connectorID, transform: Transform3D(positionX: x, positionY: y, positionZ: z))))
                }
            }
        }

        do {
            let added = try await MainActor.run { try CADDocumentStore.shared.addComponents(components) }
            return CADDesignerV2ToolSupport.localized(
                en: "Built frame (\(Int(width))×\(Int(depth))×\(Int(height)) mm).\ncomponentCount: \(added.count)\nposts: 4 × \(Int(height))mm\nbeams: 4 × \(Int(beamXLength))mm + 4 × \(Int(beamZLength))mm\nbrackets: \(connectorID == nil ? 0 : 8)\nprofile: \(profileID)",
                zh: "已生成框架（\(Int(width))×\(Int(depth))×\(Int(height)) mm）。\n组件数: \(added.count)\n立柱: 4 × \(Int(height))mm\n横梁: 4 × \(Int(beamXLength))mm + 4 × \(Int(beamZLength))mm\n角码: \(connectorID == nil ? 0 : 8)\n型材规格: \(profileID)"
            )
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADDesignerV2ToolSupport.error(error)
        }
    }
}
