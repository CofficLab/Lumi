import SwiftUI

/// 解析每个点的水平位置（0...1）。
/// 传入的 `fractions` 缺失或数量与数据不一致时回退为等距布局。
private func resolvedXFractions(_ fractions: [Double]?, count: Int) -> [Double] {
    if let fractions, fractions.count == count {
        return fractions.map { min(max($0, 0), 1) }
    }
    guard count > 1 else { return count == 1 ? [0] : [] }
    return (0..<count).map { Double($0) / Double(count - 1) }
}

public struct MiniGraphArea: Shape {
    let data: [Double]
    let maxValue: Double
    /// 每个点的水平位置（0...1）；nil 表示按数组下标等距布局。
    let xFractions: [Double]?

    public init(data: [Double], maxValue: Double, xFractions: [Double]? = nil) {
        self.data = data
        self.maxValue = maxValue
        self.xFractions = xFractions
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty, maxValue > 0 else { return path }

        let fractions = resolvedXFractions(xFractions, count: data.count)
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))

        for (i, value) in data.enumerated() {
            let x = CGFloat(fractions[i]) * rect.width
            let y = height - CGFloat(value / maxValue) * height
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: CGFloat(fractions.last ?? 0) * rect.width, y: height))
        path.closeSubpath()

        return path
    }
}

public struct MiniGraphLine: Shape {
    let data: [Double]
    let maxValue: Double
    /// 每个点的水平位置（0...1）；nil 表示按数组下标等距布局。
    let xFractions: [Double]?

    public init(data: [Double], maxValue: Double, xFractions: [Double]? = nil) {
        self.data = data
        self.maxValue = maxValue
        self.xFractions = xFractions
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty, maxValue > 0 else { return path }

        let fractions = resolvedXFractions(xFractions, count: data.count)
        let height = rect.height

        for (i, value) in data.enumerated() {
            let x = CGFloat(fractions[i]) * rect.width
            let y = height - CGFloat(value / maxValue) * height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}
