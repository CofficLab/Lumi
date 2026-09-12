import CoreGraphics
import Testing
@testable import PluginMessageListEmpty

@Test func flowLayoutReportsTheWidestWrappedRowAndPositionsEachItem() {
    let geometry = flowLayoutGeometry(
        for: [CGSize(width: 70, height: 20), CGSize(width: 40, height: 30), CGSize(width: 30, height: 10)],
        width: 120,
        spacing: 8
    )

    #expect(geometry.size == CGSize(width: 118, height: 48))
    #expect(geometry.origins == [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 78, y: 0),
        CGPoint(x: 0, y: 38),
    ])
}

@Test func flowLayoutUsesNaturalWidthWithoutWrappingAndHandlesNoItems() {
    let singleRow = flowLayoutGeometry(
        for: [CGSize(width: 40, height: 12), CGSize(width: 30, height: 18)],
        width: 100,
        spacing: 5
    )
    let empty = flowLayoutGeometry(for: [], width: 100, spacing: 5)

    #expect(singleRow.size == CGSize(width: 75, height: 18))
    #expect(singleRow.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 45, y: 0)])
    #expect(empty.size == .zero)
    #expect(empty.origins.isEmpty)
}
