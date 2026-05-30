import Foundation
import Testing
@testable import PluginHTMLEditor

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func colorParserFindsHSLAndHSLAColors() async throws {
    let css = "color: hsl(120, 100%, 25%); background: hsla(240, 100%, 50%, 0.4);"

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("hsl(120, 100%, 25%)"))
    #expect(values.contains("hsla(240, 100%, 50%, 0.4)"))
}

@Test func colorParserNearColorRecognizesHSLValue() async throws {
    let css = "border-color: hsl(0, 100%, 50%);"
    let character = (css as NSString).range(of: "100%").location

    #expect(ColorParser.isNearColor(text: css, character: character) != nil)
}

@Test func colorParserIgnoresInvalidRGBAAlphaWithoutCrashing() async throws {
    let css = "color: rgba(10, 20, 30, .);"

    let matches = ColorParser.findColors(in: css)

    #expect(matches.isEmpty)
}

@Test func colorParserIgnoresInvalidHSLAAlphaWithoutCrashing() async throws {
    let css = "color: hsla(120, 50%, 40%, .);"

    let matches = ColorParser.findColors(in: css)

    #expect(matches.isEmpty)
}
