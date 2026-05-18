import XCTest
@testable import LumiInlinePreviewKit

final class InlineHostExecutableResolverTests: XCTestCase {

    func test_candidates_includeEnvironmentMainBundleResourcesPackageAndCwdPathsInOrder() {
        let candidates = LumiInlinePreviewFacade.InlineHostExecutableResolver.candidates(
            environment: [
                LumiInlinePreviewFacade.InlineHostExecutableResolver.environmentKey: "/custom/host",
                LumiInlinePreviewFacade.InlineHostExecutableResolver.packagePathEnvironmentKey: "/package"
            ],
            mainExecutableURL: URL(fileURLWithPath: "/App/Lumi.app/Contents/MacOS/Lumi"),
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: URL(fileURLWithPath: "/App/Lumi.app/Contents/Resources"),
            currentDirectoryPath: "/cwd"
        ).map(\.path)

        XCTAssertEqual(candidates.first, "/custom/host")
        XCTAssertEqual(candidates[1], "/App/Lumi.app/Contents/MacOS/LumiInlinePreviewHostApp")
        XCTAssertEqual(candidates[2], "/App/Lumi.app/Contents/Helpers/LumiInlinePreviewHostApp")
        XCTAssertEqual(candidates[3], "/App/Lumi.app/Contents/Resources/LumiInlinePreviewHostApp")
        XCTAssertTrue(candidates.contains("/package/.build/arm64-apple-macosx/debug/LumiInlinePreviewHostApp"))
        XCTAssertTrue(candidates.contains("/package/.build/x86_64-apple-macosx/release/LumiInlinePreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/arm64-apple-macosx/debug/LumiInlinePreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/x86_64-apple-macosx/release/LumiInlinePreviewHostApp"))
    }

    func test_candidates_omitEmptyOptionalInputs() {
        let candidates = LumiInlinePreviewFacade.InlineHostExecutableResolver.candidates(
            environment: [
                LumiInlinePreviewFacade.InlineHostExecutableResolver.environmentKey: "",
                LumiInlinePreviewFacade.InlineHostExecutableResolver.packagePathEnvironmentKey: ""
            ],
            mainExecutableURL: nil,
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: nil,
            currentDirectoryPath: "/cwd"
        ).map(\.path)

        XCTAssertFalse(candidates.contains(""))
        XCTAssertEqual(candidates.first, "/App/Lumi.app/Contents/Helpers/LumiInlinePreviewHostApp")
        XCTAssertFalse(candidates.contains("/package/.build/arm64-apple-macosx/debug/LumiInlinePreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/arm64-apple-macosx/debug/LumiInlinePreviewHostApp"))
    }

    func test_resolve_returnsFirstExecutableCandidate() {
        let executablePath = "/App/Lumi.app/Contents/Helpers/LumiInlinePreviewHostApp"

        let resolved = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve(
            environment: [
                LumiInlinePreviewFacade.InlineHostExecutableResolver.environmentKey: "/custom/non-executable"
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
        let resolved = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve(
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
