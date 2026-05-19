import XCTest
@testable import LumiPreviewKit

final class InlineHostExecutableResolverTests: XCTestCase {

    func test_candidates_includeEnvironmentMainBundleResourcesPackageAndCwdPathsInOrder() {
        let candidates = LumiPreviewFacade.InlineHostExecutableResolver.candidates(
            environment: [
                LumiPreviewFacade.InlineHostExecutableResolver.environmentKey: "/custom/host",
                LumiPreviewFacade.InlineHostExecutableResolver.packagePathEnvironmentKey: "/package"
            ],
            mainExecutableURL: URL(fileURLWithPath: "/App/Lumi.app/Contents/MacOS/Lumi"),
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: URL(fileURLWithPath: "/App/Lumi.app/Contents/Resources"),
            currentDirectoryPath: "/cwd"
        ).map(\.path)

        XCTAssertEqual(candidates.first, "/custom/host")
        XCTAssertEqual(candidates[1], "/App/Lumi.app/Contents/MacOS/LumiPreviewHostApp")
        XCTAssertEqual(candidates[2], "/App/Lumi.app/Contents/Helpers/LumiPreviewHostApp")
        XCTAssertEqual(candidates[3], "/App/Lumi.app/Contents/Resources/LumiPreviewHostApp")
        XCTAssertTrue(candidates.contains("/package/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/package/.build/x86_64-apple-macosx/release/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/x86_64-apple-macosx/release/LumiPreviewHostApp"))
    }

    func test_candidates_omitEmptyOptionalInputs() {
        let candidates = LumiPreviewFacade.InlineHostExecutableResolver.candidates(
            environment: [
                LumiPreviewFacade.InlineHostExecutableResolver.environmentKey: "",
                LumiPreviewFacade.InlineHostExecutableResolver.packagePathEnvironmentKey: ""
            ],
            mainExecutableURL: nil,
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: nil,
            currentDirectoryPath: "/cwd"
        ).map(\.path)

        XCTAssertFalse(candidates.contains(""))
        XCTAssertEqual(candidates.first, "/App/Lumi.app/Contents/Helpers/LumiPreviewHostApp")
        XCTAssertFalse(candidates.contains("/package/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
    }

    func test_resolve_returnsFirstExecutableCandidate() {
        let executablePath = "/App/Lumi.app/Contents/Helpers/LumiPreviewHostApp"

        let resolved = LumiPreviewFacade.InlineHostExecutableResolver.resolve(
            environment: [
                LumiPreviewFacade.InlineHostExecutableResolver.environmentKey: "/custom/non-executable"
            ],
            mainExecutableURL: URL(fileURLWithPath: "/App/Lumi.app/Contents/MacOS/Lumi"),
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: URL(fileURLWithPath: "/App/Lumi.app/Contents/Resources"),
            currentDirectoryPath: "/cwd",
            isExecutable: { $0.path == executablePath }
        )

        XCTAssertEqual(resolved?.path, executablePath)
    }

    func test_resolve_returnsNilWhenNoCandidateIsExecutable() {
        let resolved = LumiPreviewFacade.InlineHostExecutableResolver.resolve(
            environment: [:],
            mainExecutableURL: nil,
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: nil,
            currentDirectoryPath: "/cwd",
            isExecutable: { _ in false }
        )

        XCTAssertNil(resolved)
    }
}
