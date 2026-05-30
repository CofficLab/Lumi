#if canImport(XCTest)
import XCTest
@testable import PluginHTMLEditor
@testable import Lumi

final class HTMLEditorPluginTests: XCTestCase {
    func testTagMatcherReturnsCurrentAndMatchingTags() {
        let lines = ["<div>", "  <span>Hello</span>", "</div>"]

        let match = TagMatcher.findTagPair(lines: lines, line: 0, character: 1)

        XCTAssertEqual(match?.current.name, "div")
        XCTAssertEqual(match?.current.startLine, 0)
        XCTAssertEqual(match?.matching?.name, "div")
        XCTAssertEqual(match?.matching?.startLine, 2)
        XCTAssertTrue(match?.matching?.isClosing == true)
    }

    func testEmbeddedRegionScannerUsesTagBodyRange() {
        let html = """
        <main>
        <style>
        .card { color: red; }
        </style>
        <script type="text/typescript">
        const value: string = "ok"
        </script>
        </main>
        """

        let regions = EmbeddedRegionScanner.scanRegions(in: html)

        XCTAssertEqual(regions.map(\.language), ["css", "typescript"])
        XCTAssertTrue(regions[0].virtualContent.contains(".card"))
        XCTAssertFalse(regions[0].virtualContent.contains("<style"))
    }

    func testCSSClassLinkerExtractsDefinitionsFromStyleBlock() {
        let html = """
        <style>
        .card, .panel {
          color: red;
          display: grid;
        }
        </style>
        <div class="card"></div>
        """

        let definitions = CSSClassLinker.classDefinitions(in: html)

        XCTAssertEqual(definitions.map(\.name), ["card", "panel"])
        XCTAssertEqual(CSSClassLinker.classAttributeNames(in: html), ["card"])
        XCTAssertTrue(definitions.first?.properties.contains("color: red") == true)
    }

    func testHTMLDiagnosticAggregatorReportsStructureIssues() {
        let html = """
        <div>
          <img src="hero.png">
        </section>
        """

        let diagnostics = HTMLDiagnosticAggregator.localDiagnostics(for: html)

        XCTAssertTrue(diagnostics.contains { $0.message.contains("alt attribute") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("Unexpected closing tag") })
        XCTAssertTrue(diagnostics.contains { $0.message.contains("Missing closing tag") })
    }
}
#endif
