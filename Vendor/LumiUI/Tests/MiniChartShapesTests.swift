import SwiftUI
import Testing
@testable import LumiUI

struct MiniChartShapesTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

    // MARK: - MiniGraphArea

    @Test
    @MainActor
    func areaPathIsEmptyForEmptyData() {
        let shape = MiniGraphArea(data: [], maxValue: 1)

        #expect(shape.path(in: rect).isEmpty)
    }

    @Test
    @MainActor
    func areaPathIsEmptyForNonPositiveMaxValue() {
        let zeroMax = MiniGraphArea(data: [0.5, 1.0], maxValue: 0)
        let negativeMax = MiniGraphArea(data: [0.5, 1.0], maxValue: -1)

        #expect(zeroMax.path(in: rect).isEmpty)
        #expect(negativeMax.path(in: rect).isEmpty)
    }

    @Test
    @MainActor
    func areaPathSpansFullRectAndIsClosed() {
        let shape = MiniGraphArea(data: [0, 1.0], maxValue: 1)

        let path = shape.path(in: rect)
        let bounds = path.boundingRect

        #expect(!path.isEmpty)
        #expect(bounds.minX == 0)
        #expect(bounds.maxX == rect.width)
        #expect(bounds.minY == 0)
        #expect(bounds.maxY == rect.height)
    }

    // MARK: - MiniGraphLine

    @Test
    @MainActor
    func linePathIsEmptyForEmptyData() {
        let shape = MiniGraphLine(data: [], maxValue: 1)

        #expect(shape.path(in: rect).isEmpty)
    }

    @Test
    @MainActor
    func linePathIsEmptyForNonPositiveMaxValue() {
        let shape = MiniGraphLine(data: [0.25, 0.75], maxValue: 0)

        #expect(shape.path(in: rect).isEmpty)
    }

    @Test
    @MainActor
    func linePathFollowsDataPointsWithinRect() {
        let shape = MiniGraphLine(data: [0, 0.5, 1.0], maxValue: 1)

        let path = shape.path(in: rect)
        let bounds = path.boundingRect

        #expect(!path.isEmpty)
        #expect(bounds.minX == 0)
        #expect(bounds.maxX == rect.width)
        #expect(bounds.minY == 0)
        #expect(bounds.maxY == rect.height)
    }

    @Test
    @MainActor
    func lineAndAreaPathsDifferForSameInput() {
        let data: [Double] = [0.2, 0.6, 0.4]
        let area = MiniGraphArea(data: data, maxValue: 1).path(in: rect)
        let line = MiniGraphLine(data: data, maxValue: 1).path(in: rect)

        #expect(!area.isEmpty)
        #expect(!line.isEmpty)
        #expect(area.boundingRect.height >= line.boundingRect.height)
    }

    // MARK: - 时间轴定位

    /// 回归 #732：传入 xFractions 时按给定比例布局，不再等距铺满。
    @Test
    @MainActor
    func lineUsesProvidedXFractions() {
        let points = [0.5, 0.5, 0.5]
        let shape = MiniGraphLine(data: points, maxValue: 1, xFractions: [0, 0.2, 1])

        #expect(xPositions(in: shape.path(in: rect)) == [0, 20, 100])
    }

    @Test
    @MainActor
    func areaEndsAtLastProvidedXFraction() {
        let shape = MiniGraphArea(data: [0.5, 0.5, 0.5], maxValue: 1, xFractions: [0, 0.2, 1])

        let xs = xPositions(in: shape.path(in: rect))
        // move(0, h), line(0), line(20), line(100), line(100, h)
        #expect(xs == [0, 0, 20, 100, 100])
    }

    @Test
    @MainActor
    func mismatchedFractionsFallBackToEvenSpacing() {
        let shape = MiniGraphLine(data: [0.5, 0.5, 0.5], maxValue: 1, xFractions: [0, 1])

        #expect(xPositions(in: shape.path(in: rect)) == [0, 50, 100])
    }

    private func xPositions(in path: Path) -> [CGFloat] {
        var result: [CGFloat] = []
        path.forEach { element in
            switch element {
            case let .move(point), let .line(point):
                result.append((point.x * 100).rounded() / 100)
            default:
                break
            }
        }
        return result
    }
}
