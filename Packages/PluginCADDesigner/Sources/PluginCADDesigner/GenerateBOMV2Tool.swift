import AgentToolKit
import CADDesignerPlugin
import Foundation

/// V2 implementation of the stable legacy `cad_generate_bom` tool.
public struct GenerateBOMV2Tool: SuperAgentTool {
    public static let toolName = "cad_generate_bom"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Generate the bill of materials for the current CAD project, aggregating profiles and connectors." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": [:]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Generate BOM" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let report = await MainActor.run { () -> BOMReport? in
            guard let document = CADDocumentStore.shared.selectedDocument else { return nil }
            return BOMGenerator().generate(from: document, library: .shared)
        }
        guard let report else {
            return CADDesignerV2ToolSupport.localized(en: "Error: No CAD document is selected.", zh: "错误：未选中 CAD 文档。")
        }
        if LanguagePreference.current == .chinese {
            var lines = ["物料清单（共 \(report.items.count) 项，总重 \(String(format: "%.2f", report.totalWeight)) kg）："]
            for item in report.items {
                let length = item.length > 0 ? " × \(Int(item.length))mm" : ""
                lines.append("- \(item.description)\(length) × \(item.quantity)（\(String(format: "%.2f", item.weight)) kg）")
            }
            return lines.joined(separator: "\n")
        }
        var lines = ["Bill of Materials (\(report.items.count) items, total \(String(format: "%.2f", report.totalWeight)) kg):"]
        for item in report.items {
            let length = item.length > 0 ? " × \(Int(item.length))mm" : ""
            lines.append("- \(item.description)\(length) × \(item.quantity) (\(String(format: "%.2f", item.weight)) kg)")
        }
        return lines.joined(separator: "\n")
    }
}
