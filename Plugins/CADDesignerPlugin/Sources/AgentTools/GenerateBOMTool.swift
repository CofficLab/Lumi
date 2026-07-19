import Foundation
import LumiKernel

/// 生成当前项目的物料清单。
public struct GenerateBOMTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_generate_bom",
        displayName: "Generate BOM",
        description: "Generate the bill of materials for the current CAD project, aggregating profiles and connectors."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": [:]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Generate BOM"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)

        let report = await MainActor.run {
            guard let document = CADDocumentStore.shared.selectedDocument else {
                return nil as BOMReport?
            }
            return BOMGenerator().generate(from: document, library: .shared)
        }

        guard let report else {
            return CADToolSupport.localized(
                language,
                en: "Error: No CAD document is selected.",
                zh: "错误：未选中 CAD 文档。"
            )
        }

        switch language {
        case .chinese:
            var lines = ["物料清单（共 \(report.items.count) 项，总重 \(String(format: "%.2f", report.totalWeight)) kg）："]
            for item in report.items {
                let lengthPart = item.length > 0 ? " × \(Int(item.length))mm" : ""
                lines.append("- \(item.description)\(lengthPart) × \(item.quantity)（\(String(format: "%.2f", item.weight)) kg）")
            }
            return lines.joined(separator: "\n")
        case .english:
            var lines = ["Bill of Materials (\(report.items.count) items, total \(String(format: "%.2f", report.totalWeight)) kg):"]
            for item in report.items {
                let lengthPart = item.length > 0 ? " × \(Int(item.length))mm" : ""
                lines.append("- \(item.description)\(lengthPart) × \(item.quantity) (\(String(format: "%.2f", item.weight)) kg)")
            }
            return lines.joined(separator: "\n")
        }
    }
}
