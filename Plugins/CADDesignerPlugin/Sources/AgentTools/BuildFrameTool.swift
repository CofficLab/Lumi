import Foundation
import LumiKernel

/// AI 自然语言搭框架（文档 Phase 4.1）。
///
/// 输入宽×深×高，自动生成一个矩形框架：4 立柱 + 8 横梁（顶部 4 + 底部 4）+ 4 角码连接。
/// 立柱沿 Y 轴（垂直），横梁沿 X/Z 轴。
public struct BuildFrameTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_build_frame",
        displayName: "Build Frame",
        description: "Build a rectangular aluminum profile frame from dimensions (width × depth × height in mm). Generates 4 vertical posts, 8 horizontal beams, and corner brackets. Use this for workbenches, racks, etc."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "width": ["type": "number", "description": "Frame width (X axis) in mm."],
                "depth": ["type": "number", "description": "Frame depth (Z axis) in mm."],
                "height": ["type": "number", "description": "Frame height (Y axis) in mm."],
                "series": [
                    "type": "string",
                    "enum": ["20", "30", "40"],
                    "description": "Profile series. Defaults to '40' (heavy duty).",
                ],
                "profileId": ["type": "string", "description": "Override profile spec id (e.g. 'profile-40x40-eu'). Defaults to a square profile of the chosen series."],
            ],
            "required": ["width", "depth", "height"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let w = arguments.double("width").map(Int.init) ?? 0
        let h = arguments.double("height").map(Int.init) ?? 0
        return "Build frame \(w)×\(h)"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)

        guard let width = CADToolSupport.optionalDouble(arguments, "width") else {
            return CADToolSupport.missingParameter("width", language: language)
        }
        guard let depth = CADToolSupport.optionalDouble(arguments, "depth") else {
            return CADToolSupport.missingParameter("depth", language: language)
        }
        guard let height = CADToolSupport.optionalDouble(arguments, "height") else {
            return CADToolSupport.missingParameter("height", language: language)
        }

        let seriesString = CADToolSupport.string(arguments, "series") ?? "40"
        let series = ProfileSeries(rawValue: seriesString) ?? .series40

        // 选择型材规格（优先用 profileId，否则取该系列的正方形型材）
        let profileId: String
        if let override = CADToolSupport.string(arguments, "profileId"),
           ComponentLibrary.shared.profileSpec(id: override) != nil {
            profileId = override
        } else if let square = ComponentLibrary.shared.profiles.first(where: { $0.series == series && $0.width == $0.height }) {
            profileId = square.id
        } else {
            return CADToolSupport.localized(
                language,
                en: "Error: No square profile found for series \(series.rawValue).",
                zh: "错误：\(series.rawValue) 系列未找到正方形型材。"
            )
        }

        guard let spec = ComponentLibrary.shared.profileSpec(id: profileId) else {
            return CADToolSupport.localized(
                language,
                en: "Error: Unknown profile spec '\(profileId)'.",
                zh: "错误：未知型材规格 '\(profileId)'。"
            )
        }

        let connectorId = ComponentLibrary.shared.connectors
            .first { $0.series == series && $0.kind == .cornerBracket }?.id
        let halfW = width / 2
        let halfD = depth / 2
        // 型材截面半宽，用于让框架表面齐平（立柱中心内缩）。
        let offset = spec.width / 2

        var components: [CADComponent] = []

        // 4 立柱（沿 Y 轴垂直，rotationY = 90° 使型材长度方向对齐 Y 轴）
        // 立柱中心位于 (±halfW, height/2, ±halfD)
        let postLength = height
        let postCorners: [(Double, Double)] = [(-halfW + offset, -halfD + offset),
                                               (halfW - offset, -halfD + offset),
                                               (-halfW + offset, halfD - offset),
                                               (halfW - offset, halfD - offset)]
        for (x, z) in postCorners {
            let post = ProfileInstance(
                profileId: profileId,
                length: postLength,
                transform: Transform3D(positionX: x, positionY: height / 2, positionZ: z, rotationX: 0, rotationY: 0, rotationZ: 90)
            )
            components.append(.profile(post))
        }

        // 横梁：顶部 4 + 底部 4
        // X 向横梁（长度 = width - 2*spec.width）沿 X 轴
        let beamXLength = max(width - 2 * spec.width, 10)
        // Z 向横梁（长度 = depth - 2*spec.width）沿 Z 轴（rotationY = 90）
        let beamZLength = max(depth - 2 * spec.width, 10)

        for y in [spec.width / 2, height - spec.width / 2] {
            // 2 根 X 向横梁（前、后），沿 X 轴，位于 z = ±(halfD - offset)
            for z in [-(halfD - offset), halfD - offset] {
                let beam = ProfileInstance(
                    profileId: profileId,
                    length: beamXLength,
                    transform: Transform3D(positionX: 0, positionY: y, positionZ: z, rotationY: 0)
                )
                components.append(.profile(beam))
            }
            // 2 根 Z 向横梁（左、右），沿 Z 轴
            for x in [-(halfW - offset), halfW - offset] {
                let beam = ProfileInstance(
                    profileId: profileId,
                    length: beamZLength,
                    transform: Transform3D(positionX: x, positionY: y, positionZ: 0, rotationY: 90)
                )
                components.append(.profile(beam))
            }
        }

        // 角码连接件（4 个顶角）
        if let connectorId {
            for (x, z) in postCorners {
                for y in [spec.width / 2, height - spec.width / 2] {
                    let connector = ConnectorInstance(
                        connectorId: connectorId,
                        transform: Transform3D(positionX: x, positionY: y, positionZ: z)
                    )
                    components.append(.connector(connector))
                }
            }
        }

        let added = try await MainActor.run {
            try CADDocumentStore.shared.addComponents(components)
        }

        switch language {
        case .chinese:
            return """
            已生成框架（\(Int(width))×\(Int(depth))×\(Int(height)) mm）。
            组件数: \(added.count)
            立柱: 4 × \(Int(postLength))mm
            横梁: 4 × \(Int(beamXLength))mm + 4 × \(Int(beamZLength))mm
            角码: \(connectorId == nil ? 0 : 8)
            型材规格: \(profileId)
            """
        case .english:
            return """
            Built frame (\(Int(width))×\(Int(depth))×\(Int(height)) mm).
            componentCount: \(added.count)
            posts: 4 × \(Int(postLength))mm
            beams: 4 × \(Int(beamXLength))mm + 4 × \(Int(beamZLength))mm
            brackets: \(connectorId == nil ? 0 : 8)
            profile: \(profileId)
            """
        }
    }
}
