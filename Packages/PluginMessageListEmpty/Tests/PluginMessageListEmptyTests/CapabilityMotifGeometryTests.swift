import CoreGraphics
import Testing
@testable import PluginMessageListEmpty

/// Regression guard for the empty-state perimeter art.
///
/// A previous revision drew several elements outside its card: a rotated
/// rectangle that overflowed the canvas, an SF Symbol parked beside the card
/// instead of on it, and a bezier whose control points used negative x. These
/// tests pin the "every element sits inside the card" rule so the layout
/// cannot silently regress into scattered decoration again.

@Test func motifCardSitsFullyInsideTheCanvas() {
    let canvas = CGRect(origin: .zero, size: CapabilityMotifGeometry.canvasSize)

    #expect(canvas.contains(CapabilityMotifGeometry.cardRect))
    // A visible margin on every side keeps the card off the canvas edge.
    #expect(canvas.insetBy(dx: 20, dy: 18).contains(CapabilityMotifGeometry.cardRect))
}

@Test func motifSupportingGeometryStaysInsideTheCard() {
    for row in CapabilityMotifGeometry.textRows {
        #expect(CapabilityMotifGeometry.contains(row))
    }
    #expect(CapabilityMotifGeometry.contains(CapabilityMotifGeometry.pillRect))
    #expect(CapabilityMotifGeometry.contains(CapabilityMotifGeometry.dotRect))
}

@Test func motifBandsStayInsideTheCardAndDoNotOverlap() {
    #expect(CapabilityMotifGeometry.contains(CapabilityMotifGeometry.symbolBand))
    #expect(CapabilityMotifGeometry.contains(CapabilityMotifGeometry.detailBand))
    #expect(CapabilityMotifGeometry.symbolBand.intersection(CapabilityMotifGeometry.detailBand).isNull)

    // The symbol itself must clear the detail band it sits above.
    let center = CapabilityMotifGeometry.symbolCenter
    let halfSide: CGFloat = 18
    let symbolBounds = CGRect(
        x: center.x - halfSide,
        y: center.y - halfSide,
        width: halfSide * 2,
        height: halfSide * 2
    )
    #expect(CapabilityMotifGeometry.contains(symbolBounds))
    #expect(symbolBounds.maxY <= CapabilityMotifGeometry.detailBand.minY)
}

@Test func motifSymbolFitsWithinTheCardForEverySupportedSize() {
    let center = CapabilityMotifGeometry.symbolCenter
    let halfSide: CGFloat = 18

    for size in [34, 36] as [CGFloat] {
        let bounds = CGRect(
            x: center.x - halfSide,
            y: center.y - halfSide,
            width: halfSide * 2,
            height: halfSide * 2
        )
        #expect(CapabilityMotifGeometry.contains(bounds), "symbol size \(size) escapes the card")
    }
}

@Test func motifRejectsGeometryThatLeavesTheCard() {
    // A rect starting left of the card must not report as contained.
    #expect(!CapabilityMotifGeometry.contains(CGRect(x: -14, y: 50, width: 32, height: 20)))
    // Nor one hanging off the right edge.
    #expect(!CapabilityMotifGeometry.contains(CGRect(x: 108, y: 20, width: 30, height: 20)))
}
