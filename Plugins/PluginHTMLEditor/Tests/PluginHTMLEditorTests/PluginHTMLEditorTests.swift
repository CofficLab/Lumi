import Foundation
import Testing
@testable import PluginHTMLEditor

@Test func colorParserFindsHSLAndHSLAColors() async throws {
    let css = "color: hsl(120, 100%, 25%); background: hsla(240, 100%, 50%, 0.4);"

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("hsl(120, 100%, 25%)"))
    #expect(values.contains("hsla(240, 100%, 50%, 0.4)"))
}

@Test func colorParserFindsModernSpaceSeparatedRGBAndHSLColors() async throws {
    let css = "color: rgb(255 0 0 / 50%); background: hsl(-120 100% 25% / 0.4);"

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("rgb(255 0 0 / 50%)"))
    #expect(values.contains("hsl(-120 100% 25% / 0.4)"))
}

@Test func colorParserFindsHSLColorsWithAngleUnits() async throws {
    let css = """
    color: hsl(120deg 100% 25%);
    background: hsl(.5turn 100% 50% / 40%);
    border-color: hsl(200grad 80% 40%);
    outline-color: hsl(3.14159rad 100% 50%);
    """

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("hsl(120deg 100% 25%)"))
    #expect(values.contains("hsl(.5turn 100% 50% / 40%)"))
    #expect(values.contains("hsl(200grad 80% 40%)"))
    #expect(values.contains("hsl(3.14159rad 100% 50%)"))
}

@Test func colorParserFindsRGBPercentChannels() async throws {
    let css = "border-color: rgba(100% 0% 50% / 25%);"

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("rgba(100% 0% 50% / 25%)"))
}

@Test func colorParserFindsHexColorsWithAlphaChannels() async throws {
    let css = "color: #0f08; background: #336699cc;"

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("#0f08"))
    #expect(values.contains("#336699cc"))
}

@Test func colorParserNearColorRecognizesHSLValue() async throws {
    let css = "border-color: hsl(0, 100%, 50%);"
    let character = (css as NSString).range(of: "100%").location

    #expect(ColorParser.isNearColor(text: css, character: character) != nil)
}

@Test func colorParserNearColorRecognizesHexAlphaValue() async throws {
    let css = "background-color: #336699cc;"
    let character = (css as NSString).range(of: "699").location

    #expect(ColorParser.isNearColor(text: css, character: character) != nil)
}

@Test func colorParserIgnoresInvalidRGBAAlphaWithoutCrashing() async throws {
    let css = "color: rgba(10, 20, 30, .);"

    let matches = ColorParser.findColors(in: css)

    #expect(matches.isEmpty)
}

@Test func colorParserFindsStandaloneNamedColors() async throws {
    let css = "color: red; box-shadow: 0 0 2px blue, inset 0 0 1px green;"

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values.contains("red"))
    #expect(values.contains("blue"))
    #expect(values.contains("green"))
}

@Test func colorParserIgnoresNamedColorsInsideIdentifiers() async throws {
    let css = """
    .blue-button { --red-color: #123456; }
    .card[data-tone="greenish"] { color: #red; }
    """

    let matches = ColorParser.findColors(in: css)
    let values = matches.map(\.hexString)

    #expect(values == ["#123456"])
}

@Test func colorParserIgnoresInvalidHSLAAlphaWithoutCrashing() async throws {
    let css = "color: hsla(120, 50%, 40%, .);"

    let matches = ColorParser.findColors(in: css)

    #expect(matches.isEmpty)
}
