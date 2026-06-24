import Testing
import Foundation
@testable import AppIconDesignerPlugin

/// Unit tests for `IconColorHex.normalized` color validation and `IconSVGRenderer`
/// number formatting / escaping behavior.
@Suite struct IconColorHexTests {

    @Test func normalizesSixDigitHex() {
        #expect(IconColorHex.normalized("ff0000") == "#ff0000")
        #expect(IconColorHex.normalized("#ff0000") == "#ff0000")
    }

    @Test func normalizesEightDigitHexWithAlpha() {
        #expect(IconColorHex.normalized("ff0000ff") == "#ff0000ff")
        #expect(IconColorHex.normalized("#00000000") == "#00000000")
    }

    @Test func trimsWhitespace() {
        #expect(IconColorHex.normalized("  ff0000  ") == "#ff0000")
    }

    @Test func acceptsUppercaseAndLowercase() {
        #expect(IconColorHex.normalized("ABCDEF") == "#ABCDEF")
        #expect(IconColorHex.normalized("abcdef") == "#abcdef")
    }

    @Test func rejectsWrongLength() {
        #expect(IconColorHex.normalized("fff") == "#00000000")
        #expect(IconColorHex.normalized("ff0000ff00") == "#00000000")
        #expect(IconColorHex.normalized("") == "#00000000")
    }

    @Test func rejectsNonHexCharacters() {
        #expect(IconColorHex.normalized("gg0000") == "#00000000")
        #expect(IconColorHex.normalized("ff-000") == "#00000000")
    }

    @Test func usesCustomFallback() {
        #expect(IconColorHex.normalized("bad", fallback: "#ffffffff") == "#ffffffff")
    }
}

@Suite struct IconSVGRendererTests {

    private func makeDocument(layers: [IconLayer] = [], background: IconPaint = .color("#00000000")) -> IconDocument {
        IconDocument(id: "test", title: "Test", width: 1024, height: 1024, background: background, layers: layers)
    }

    @Test func rendersSvgHeaderWithIntegerDimensions() {
        let svg = IconSVGRenderer().render(document: makeDocument())
        // Integer dimensions render without decimals (number() integer path).
        #expect(svg.contains("width=\"1024\""))
        #expect(svg.contains("height=\"1024\""))
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test func omitsTransparentBackground() {
        let svg = IconSVGRenderer().render(document: makeDocument(background: .color("#00000000")))
        // Fully transparent default background must not emit a rect.
        #expect(!svg.contains("<rect x=\"0\" y=\"0\""))
    }

    @Test func emitsOpaqueBackground() {
        let svg = IconSVGRenderer().render(document: makeDocument(background: .color("#ff0000ff")))
        #expect(svg.contains("fill=\"#ff0000ff\""))
    }

    @Test func rendersRectangleLayer() {
        let layer = IconLayer(name: "box", shape: .rectangle(x: 0, y: 0, width: 100, height: 100, cornerRadius: 8),
                              fill: .color("#00ff00ff"))
        let svg = IconSVGRenderer().render(document: makeDocument(layers: [layer]))
        #expect(svg.contains("<rect"))
        #expect(svg.contains("rx=\"8\""))
        #expect(svg.contains("fill=\"#00ff00ff\""))
    }

    @Test func rendersCircleLayer() {
        let layer = IconLayer(name: "dot", shape: .circle(cx: 50, cy: 50, radius: 40), fill: .color("#0000ffff"))
        let svg = IconSVGRenderer().render(document: makeDocument(layers: [layer]))
        #expect(svg.contains("<circle"))
        #expect(svg.contains("r=\"40\""))
    }

    @Test func numberFormatsFractionalWithoutTrailingZeros() {
        // A layer with fractional coordinates exercises the decimal formatting path.
        let layer = IconLayer(name: "f", shape: .rectangle(x: 1.5, y: 2.25, width: 100, height: 100, cornerRadius: 0),
                              fill: .color("#ff0000ff"))
        let svg = IconSVGRenderer().render(document: makeDocument(layers: [layer]))
        #expect(svg.contains("x=\"1.5\""))
        #expect(svg.contains("y=\"2.25\""))
        // No accidental decimal stripping of integer "100".
        #expect(svg.contains("width=\"100\""))
    }

    @Test func escapesXmlEntitiesInLayerId() {
        let layer = IconLayer(id: "a<b>&\"x\"", name: "n", shape: .circle(cx: 0, cy: 0, radius: 1), fill: .color("#ffffffff"))
        let svg = IconSVGRenderer().render(document: makeDocument(layers: [layer]))
        #expect(svg.contains("id=\"a&lt;b&gt;&amp;&quot;x&quot;\""))
    }

    @Test func capsuleUsesHalfHeightRadius() {
        let layer = IconLayer(name: "cap", shape: .capsule(x: 0, y: 0, width: 200, height: 100), fill: .color("#ffffffff"))
        let svg = IconSVGRenderer().render(document: makeDocument(layers: [layer]))
        #expect(svg.contains("rx=\"50\""))
    }
}
