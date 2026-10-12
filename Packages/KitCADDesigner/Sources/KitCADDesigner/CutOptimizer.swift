import Foundation

/// 单根原料上的切割方案。
public struct CutStockResult: Identifiable, Equatable, Sendable {
    public let id: String
    /// 本根原料被切出的需求长度列表（降序）。
    public let cuts: [Double]
    /// 剩余余料（mm）。
    public let remainder: Double
    /// 利用率（0-1）。
    public let utilization: Double

    public init(id: String = UUID().uuidString, cuts: [Double], remainder: Double, utilization: Double) {
        self.id = id
        self.cuts = cuts
        self.remainder = remainder
        self.utilization = utilization
    }
}

/// 切割优化整体结果。
public struct CutOptimizationResult: Equatable, Sendable {
    public let stocks: [CutStockResult]
    /// 所用原料数。
    public let stockCount: Int
    /// 总余料（mm）。
    public let totalRemainder: Double
    /// 总利用率。
    public let totalUtilization: Double

    public init(stocks: [CutStockResult], stockCount: Int, totalRemainder: Double, totalUtilization: Double) {
        self.stocks = stocks
        self.stockCount = stockCount
        self.totalRemainder = totalRemainder
        self.totalUtilization = totalUtilization
    }
}

/// 一维切割优化（Cutting Stock Problem），使用 First Fit Decreasing (FFD) 启发式算法（文档第 4.7 节）。
///
/// 算法：需求长度降序排序 → 逐个放入第一个能容纳的原料条；若无可用则开新条。
public struct CutOptimizer {
    public init() {}

    /// 对一组需求长度做切割优化。
    ///
    /// - Parameters:
    ///   - demands: 需求长度列表（mm）。
    ///   - stockLength: 单根原料长度（mm），默认 6000mm 欧标。
    /// - Returns: 切割方案。
    public func optimize(demands: [Double], stockLength: Double = 6000) -> CutOptimizationResult {
        let validDemands = demands
            .filter { $0 > 0 && $0 <= stockLength }
            .sorted(by: >)

        guard !validDemands.isEmpty else {
            return CutOptimizationResult(stocks: [], stockCount: 0, totalRemainder: 0, totalUtilization: 0)
        }

        // bins[i] = (已用长度, 切割列表)
        var bins: [(used: Double, cuts: [Double])] = []

        for demand in validDemands {
            if let index = bins.firstIndex(where: { $0.used + demand <= stockLength + 1e-6 }) {
                bins[index].used += demand
                bins[index].cuts.append(demand)
            } else {
                bins.append((demand, [demand]))
            }
        }

        let stocks = bins.map { bin in
            let remainder = stockLength - bin.used
            let utilization = bin.used / stockLength
            return CutStockResult(cuts: bin.cuts, remainder: remainder, utilization: utilization)
        }

        let totalUsed = bins.map(\.used).reduce(0, +)
        let totalStock = Double(stocks.count) * stockLength
        let totalRemainder = totalStock - totalUsed
        let totalUtilization = totalStock > 0 ? totalUsed / totalStock : 0

        return CutOptimizationResult(
            stocks: stocks,
            stockCount: stocks.count,
            totalRemainder: totalRemainder,
            totalUtilization: totalUtilization
        )
    }
}
