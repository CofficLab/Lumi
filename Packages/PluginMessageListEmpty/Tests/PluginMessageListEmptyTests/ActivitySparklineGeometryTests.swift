import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListEmpty

/// 曲线与画布之间的坐标映射。
///
/// Canvas 里画错了不会让编译失败，只会在界面上留下一根歪掉的线；因此这里
/// 把「点一定落在画布内」「峰值贴着顶边」「等值序列是一条直线」这些不变量
/// 变成可断言的契约。
@Suite("Activity sparkline geometry")
struct ActivitySparklineGeometryTests {
    private let size = CGSize(width: 300, height: 56)

    @Test("an empty series draws nothing")
    func emptySeriesHasNoPoints() {
        #expect(ActivitySparklineGeometry.points(values: [], size: size).isEmpty)
    }

    @Test("a zero-sized canvas draws nothing")
    func zeroSizedCanvasHasNoPoints() {
        let values: [Double] = [1, 2, 3]
        #expect(ActivitySparklineGeometry.points(values: values, size: .zero).isEmpty)
        #expect(
            ActivitySparklineGeometry.points(values: values, size: CGSize(width: 0, height: 56)).isEmpty
        )
    }

    @Test("the peak sits at the top of the canvas and the valley near the bottom")
    func peakAndValleyAnchorToTheCanvas() {
        let values: [Double] = [0, 5, 0]
        let points = ActivitySparklineGeometry.points(values: values, size: size)

        #expect(points.count == 3)
        #expect(points[1].y == ActivitySparklineGeometry.verticalInset)
        #expect(points[0].y > points[1].y)
        #expect(points[2].y == points[0].y)
    }

    @Test("every point stays inside the canvas")
    func pointsStayInsideTheCanvas() {
        let values: [Double] = [0, 3, 9, 1, 7, 0, 4]
        let points = ActivitySparklineGeometry.points(values: values, size: size)

        for point in points {
            #expect(point.x >= 0)
            #expect(point.x <= size.width)
            #expect(point.y >= 0)
            #expect(point.y <= size.height)
        }
    }

    @Test("the series is normalized against its own peak")
    func normalizationIsRelativeToThePeak() {
        // 两个量级完全不同的序列，映射出的形状必须一致：否则"用得少"的
        // 用户会看到一条贴底的直线。
        let small = ActivitySparklineGeometry.points(values: [1, 2, 4], size: size)
        let large = ActivitySparklineGeometry.points(values: [100, 200, 400], size: size)

        #expect(small.map(\.y) == large.map(\.y))
    }

    @Test("a flat series becomes a horizontal line")
    func flatSeriesIsHorizontal() {
        let points = ActivitySparklineGeometry.points(values: [3, 3, 3, 3], size: size)

        #expect(Set(points.map(\.y)).count == 1)
    }

    @Test("a single sample is centered horizontally")
    func singleSampleIsCentered() {
        let points = ActivitySparklineGeometry.points(values: [5], size: size)

        #expect(points.count == 1)
        #expect(abs(points[0].x - size.width / 2) < 0.001)
    }
}
