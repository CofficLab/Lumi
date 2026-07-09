import Foundation
import LumiCoreKit

/// 切割优化：对项目中的型材需求长度做一维切割优化（FFD 算法）。
public struct OptimizeCuttingTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_optimize_cutting",
        displayName: "Optimize Cutting",
        description: "Run first-fit-decreasing cut optimization on all profile lengths in the current project to minimize waste."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "stockLength": ["type": "number", "description": "Standard stock length in mm. Defaults to 6000."],
            ],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Optimize cutting"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        let stockLength = CADToolSupport.double(arguments, "stockLength", default: 6000)

        let result = await MainActor.run {
            guard let document = CADDocumentStore.shared.selectedDocument else {
                return nil as CutOptimizationResult?
            }
            let demands = document.components.compactMap { component -> Double? in
                if case .profile(let instance) = component {
                    return instance.length
                }
                return nil
            }
            return CutOptimizer().optimize(demands: demands, stockLength: stockLength)
        }

        guard let result else {
            return CADToolSupport.localized(
                language,
                en: "Error: No CAD document is selected.",
                zh: "错误：未选中 CAD 文档。"
            )
        }

        switch language {
        case .chinese:
            var lines = [
                "切割优化结果：",
                "原料数: \(result.stockCount) × \(Int(stockLength))mm",
                "总利用率: \(String(format: "%.1f%%", result.totalUtilization * 100))",
                "总余料: \(Int(result.totalRemainder))mm",
                "",
            ]
            for (index, stock) in result.stocks.enumerated() {
                lines.append("原料 #\(index + 1)：\(stock.cuts.map { "\(Int($0))" }.joined(separator: " + ")) mm（余 \(Int(stock.remainder))mm）")
            }
            return lines.joined(separator: "\n")
        case .english:
            var lines = [
                "Cut optimization result:",
                "stocks: \(result.stockCount) × \(Int(stockLength))mm",
                "utilization: \(String(format: "%.1f%%", result.totalUtilization * 100))",
                "total remainder: \(Int(result.totalRemainder))mm",
                "",
            ]
            for (index, stock) in result.stocks.enumerated() {
                lines.append("Stock #\(index + 1): \(stock.cuts.map { "\(Int($0))" }.joined(separator: " + ")) mm (remainder \(Int(stock.remainder))mm)")
            }
            return lines.joined(separator: "\n")
        }
    }
}
