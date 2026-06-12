import XCTest
@testable import LumiPreviewKit

final class HostExecutableResolverTests: XCTestCase {

    func test_candidates_includeEnvironmentMainBundleResourcesPackageAndCwdPathsInOrder() {
        let candidates = LumiPreviewFacade.HostExecutableResolver.candidates(
            environment: [
                LumiPreviewFacade.HostExecutableResolver.environmentKey: "/custom/host",
                LumiPreviewFacade.HostExecutableResolver.packagePathEnvironmentKey: "/package"
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
        XCTAssertEqual(candidates[4], "/App/LumiPreviewHostApp")
        XCTAssertTrue(candidates.contains("/package/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/package/.build/x86_64-apple-macosx/release/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains("/cwd/.build/x86_64-apple-macosx/release/LumiPreviewHostApp"))
    }

    func test_candidates_omitEmptyOptionalInputs() {
        let candidates = LumiPreviewFacade.HostExecutableResolver.candidates(
            environment: [
                LumiPreviewFacade.HostExecutableResolver.environmentKey: "",
                LumiPreviewFacade.HostExecutableResolver.packagePathEnvironmentKey: ""
            ],
            mainExecutableURL: nil,
            bundleURL: URL(fileURLWithPath: "/App/Lumi.app"),
            resourceURL: nil,
            currentDirectoryPath: "/cwd"
        ).map(\.path)

        XCTAssertFalse(candidates.contains(""))
        XCTAssertEqual(candidates.first, "/App/Lumi.app/Contents/Helpers/LumiPreviewHostApp")
        XCTAssertTrue(candidates.contains("/App/LumiPreviewHostApp"))
        XCTAssertFalse(candidates.contains("/package/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
        XCTAssertTrue(candidates.contains { $0.hasSuffix("/Packages/LumiPreviewKit/.build/arm64-apple-macosx/debug/LumiPreviewHostApp") })
        XCTAssertTrue(candidates.contains("/cwd/.build/arm64-apple-macosx/debug/LumiPreviewHostApp"))
    }

    func test_resolve_returnsFirstExecutableCandidate() {
        let executablePath = "/App/Lumi.app/Contents/Helpers/LumiPreviewHostApp"

        let resolved = LumiPreviewFacade.HostExecutableResolver.resolve(
            environment: [
                LumiPreviewFacade.HostExecutableResolver.environmentKey: "/custom/non-executable"
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
        let resolved = LumiPreviewFacade.HostExecutableResolver.resolve(
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
