#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class LSPCoordinatorDefinitionTests: XCTestCase {
    func testRequestDefinitionReturnsSameTargetLocation() async {
        let expected = makeLocation(
            uri: "file:///tmp/LumiApp/Feature/Renderer.swift",
            line: 12,
            character: 4
        )
        let coordinator = LSPCoordinator(
            requestDefinitionOperation: { _, _, _ in expected }
        )
        coordinator.fileURI = "file:///tmp/LumiApp/Feature/View.swift"

        let result = await coordinator.requestDefinition(line: 8, character: 9)

        XCTAssertEqual(result?.uri, expected.uri)
        XCTAssertEqual(result?.range.start.line, expected.range.start.line)
        XCTAssertEqual(result?.range.start.character, expected.range.start.character)
    }

    func testRequestDefinitionReturnsCrossTargetLocation() async {
        let expected = makeLocation(
            uri: "file:///tmp/LumiTests/Support/TestHarness.swift",
            line: 4,
            character: 0
        )
        let coordinator = LSPCoordinator(
            requestDefinitionOperation: { _, _, _ in expected }
        )
        coordinator.fileURI = "file:///tmp/LumiApp/Shared/Protocol.swift"

        let result = await coordinator.requestDefinition(line: 15, character: 6)

        XCTAssertEqual(result?.uri, expected.uri)
        XCTAssertEqual(result?.range.start.line, 4)
    }

    func testRequestDefinitionReturnsSystemFrameworkLocation() async {
        let expected = makeLocation(
            uri: "file:///Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface",
            line: 220,
            character: 0
        )
        let coordinator = LSPCoordinator(
            requestDefinitionOperation: { _, _, _ in expected }
        )
        coordinator.fileURI = "file:///tmp/LumiApp/Views/ContentView.swift"

        let result = await coordinator.requestDefinition(line: 9, character: 3)

        XCTAssertEqual(result?.uri, expected.uri)
        XCTAssertEqual(result?.range.start.line, 220)
    }

    func testRequestDefinitionReturnsSwiftPackageCheckoutLocation() async {
        let expected = makeLocation(
            uri: "file:///Users/test/Library/Developer/Xcode/DerivedData/Lumi/SourcePackages/checkouts/Alamofire/Source/Core/Session.swift",
            line: 31,
            character: 8
        )
        let coordinator = LSPCoordinator(
            requestDefinitionOperation: { _, _, _ in expected }
        )
        coordinator.fileURI = "file:///tmp/LumiApp/Network/HTTPClient.swift"

        let result = await coordinator.requestDefinition(line: 22, character: 11)

        XCTAssertEqual(result?.uri, expected.uri)
        XCTAssertEqual(result?.range.start.character, 8)
    }

    private func makeLocation(uri: String, line: Int, character: Int) -> Location {
        Location(
            uri: uri,
            range: .init(
                start: .init(line: line, character: character),
                end: .init(line: line, character: character + 1)
            )
        )
    }
}
#endif
