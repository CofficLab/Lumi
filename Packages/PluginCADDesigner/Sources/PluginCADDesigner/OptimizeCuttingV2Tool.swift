import AgentToolKit
import CADDesignerPlugin
import Foundation

/// V2 implementation of the stable legacy `cad_optimize_cutting` tool.
public struct OptimizeCuttingV2Tool: SuperAgentTool {
    public static let toolName = "cad_optimize_cutting"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Run first-fit-decreasing cut optimization on all profile lengths in the current project to minimize waste." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["stockLength": ["type": "number", "description": "Standard stock length in mm. Defaults to 6000."]]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Optimize cutting" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let stockLength = CADDesignerV2ToolSupport.double(arguments, "stockLength", default: 6000)
        let result = await MainActor.run { () -> CutOptimizationResult? in
            guard let document = CADDocumentStore.shared.selectedDocument else { return nil }
            let demands = document.components.compactMap { if case .profile(let instance) = $0 { instance.length } else { nil } }
            return CutOptimizer().optimize(demands: demands, stockLength: stockLength)
        }
        guard let result else { return CADDesignerV2ToolSupport.localized(en: "Error: No CAD document is selected.", zh: "错误：未选中 CAD 文档。") }
        if LanguagePreference.current == .chinese {
            var lines = ["切割优化结果：", "原料数: \(result.stockCount) × \(Int(stockLength))mm", "总利用率: \(String(format: "%.1f%%", result.totalUtilization * 100))", "总余料: \(Int(result.totalRemainder))mm", ""]
            for (index, stock) in result.stocks.enumerated() { lines.append("原料 #\(index + 1)：\(stock.cuts.map { "\(Int($0))" }.joined(separator: " + ")) mm（余 \(Int(stock.remainder))mm）") }
            return lines.joined(separator: "\n")
        }
        var lines = ["Cut optimization result:", "stocks: \(result.stockCount) × \(Int(stockLength))mm", "utilization: \(String(format: "%.1f%%", result.totalUtilization * 100))", "total remainder: \(Int(result.totalRemainder))mm", ""]
        for (index, stock) in result.stocks.enumerated() { lines.append("Stock #\(index + 1): \(stock.cuts.map { "\(Int($0))" }.joined(separator: " + ")) mm (remainder \(Int(stock.remainder))mm)") }
        return lines.joined(separator: "\n")
    }
}
