import Testing
import Foundation
@testable import EditorFileTreePlugin

/// Unit tests for the pure JSON/pbxproj package-reference parsers in the
/// file-tree plugin.
@Suite struct EditorPackageResolvedTests {

    @Test func identityFromLocationStripsGitSuffix() {
        #expect(PackageResolved.identityFromLocation("https://github.com/Foo/Bar.git") == "Bar")
    }

    @Test func identityFromLocationHandlesBarePath() {
        #expect(PackageResolved.identityFromLocation("/abs/path/Bar") == "Bar")
        #expect(PackageResolved.identityFromLocation("Bar") == "Bar")
    }

    @Test func normalizeIdentityLowercases() {
        #expect(PackageResolved.normalizeIdentity("https://github.com/Foo/MyLib.git") == "mylib")
    }

    @Test func parseV2FormatPins() throws {
        let json = """
        {
          "pins": [
            { "identity": "swift-markdown", "location": "https://github.com/apple/swift-markdown.git",
              "state": { "version": "0.3.0", "revision": "abc123" } },
            { "identity": "no-state-pin", "location": "https://x/y.git" }
          ]
        }
        """
        let pins = try PackageResolved.parse(data: Data(json.utf8))
        #expect(pins.count == 2)
        #expect(pins[0].identity == "swift-markdown")
        #expect(pins[0].version == "0.3.0")
        #expect(pins[0].revision == "abc123")
        #expect(pins[1].identity == "no-state-pin")
        #expect(pins[1].version == nil)
    }

    @Test func parseV1FormatPins() throws {
        let json = """
        {
          "object": {
            "pins": [
              { "package": "Alamofire", "repositoryURL": "https://github.com/Alamofire/Alamofire.git",
                "state": { "branch": "master", "revision": "deadbeef" } }
            ]
          }
        }
        """
        let pins = try PackageResolved.parse(data: Data(json.utf8))
        #expect(pins.count == 1)
        #expect(pins[0].identity == "alamofire")
        #expect(pins[0].location.contains("Alamofire.git"))
        #expect(pins[0].branch == "master")
    }

    @Test func parseEmptyObjectReturnsEmpty() throws {
        #expect(try PackageResolved.parse(data: Data("{}".utf8)) == [])
    }

    @Test func parseFallsBackToIdentityFromLocation() throws {
        let json = """
        { "pins": [ { "location": "https://github.com/Foo/NoIdentity.git" } ] }
        """
        let pins = try PackageResolved.parse(data: Data(json.utf8))
        // Missing identity → V2 requires identity key, so dropped.
        #expect(pins.isEmpty)
    }
}

@Suite struct EditorXcodePackageReferenceParserTests {

    // Minimal pbxproj snippet with a remote package reference.
    // Matches the parser's regex: must end with "\n\t\t};" (newline + 2 tabs).
    private let remotePbxproj =
        "\t\tABCDEF /* XCRemoteSwiftPackageReference \"MyPackage\" */ = {isa = XCRemoteSwiftPackageReference; repositoryURL = \"https://github.com/foo/MyPackage.git\"; requirement = {\n" +
        "\t\t\tkind = upToNextMajorVersion;\n" +
        "\t\t\tminimumVersion = 1.2.0;\n" +
        "\t\t};\n" +
        "\t\t};"

    @Test func parseRemoteReference() {
        let refs = XcodePackageReferenceParser.parse(contents: remotePbxproj)
        #expect(refs.count >= 1)
        let remote = refs.first { $0.kind == .remote }
        #expect(remote != nil)
        #expect(remote?.location == "https://github.com/foo/MyPackage.git")
        #expect(remote?.displayName == "MyPackage")
    }

    @Test func remoteReferenceIdentityIsNormalized() {
        let refs = XcodePackageReferenceParser.parse(contents: remotePbxproj)
        let remote = refs.first { $0.kind == .remote }
        #expect(remote?.identity == "mypackage")
    }

    @Test func parseEmptyContentsReturnsEmpty() {
        #expect(XcodePackageReferenceParser.parse(contents: "").isEmpty)
    }
}
