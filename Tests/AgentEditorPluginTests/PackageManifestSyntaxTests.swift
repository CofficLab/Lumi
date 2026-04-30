#if canImport(XCTest)
import XCTest
@testable import Lumi

final class PackageManifestSyntaxTests: XCTestCase {
    func testDependencyLinkMatchesCursorInsidePackageURL() {
        let content = """
        let package = Package(
            dependencies: [
                .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
            ]
        )
        """

        let cursor = (content as NSString).range(of: "swift-argument-parser").location
        let link = PackageManifestSyntax.dependencyLink(at: cursor, in: content)

        XCTAssertEqual(link?.rawURL, "https://github.com/apple/swift-argument-parser.git")
        XCTAssertEqual(link?.url.host, "github.com")
    }

    func testDependencyLinkReturnsNilOutsideURLLiteral() {
        let content = #".package(url: "https://github.com/example/demo.git", from: "1.0.0")"#
        let cursor = (content as NSString).range(of: "from").location

        XCTAssertNil(PackageManifestSyntax.dependencyLink(at: cursor, in: content))
    }

    func testDependencyParsesVersionRequirementInsidePackageInvocation() {
        let content = """
        let package = Package(
            dependencies: [
                .package(url: "https://github.com/apple/swift-collections.git", .upToNextMinor(from: "1.2.0"))
            ]
        )
        """

        let cursor = (content as NSString).range(of: "1.2.0").location
        let dependency = PackageManifestSyntax.dependency(at: cursor, in: content)

        XCTAssertEqual(dependency?.repositoryName, "swift-collections")
        XCTAssertEqual(dependency?.requirement?.kind, .upToNextMinor)
        XCTAssertEqual(dependency?.requirement?.value, "1.2.0")
    }

    func testHoverMarkdownIncludesRepositoryAndRequirement() {
        let content = """
        let package = Package(
            dependencies: [
                .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0")
            ]
        )
        """

        let markdown = PackageManifestSyntax.hoverMarkdown(line: 2, character: 30, in: content)

        XCTAssertNotNil(markdown)
        XCTAssertTrue(markdown?.contains("swift-snapshot-testing") == true)
        XCTAssertTrue(markdown?.contains("from 1.17.0") == true)
    }
}
#endif
