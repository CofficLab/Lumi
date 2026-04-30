#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorTitleMetadataTests: XCTestCase {
    func testBuildUsesProjectRelativeParentPathAndAllRequestedBadges() {
        let metadata = EditorTitleMetadata.build(
            fileURL: URL(fileURLWithPath: "/tmp/workspace/Sources/Feature/FooView.swift"),
            projectRootPath: "/tmp/workspace",
            fileName: "FooView.swift",
            fileExtension: "swift",
            detectedLanguageName: "swift",
            isPreview: true,
            isPinned: true,
            isDirty: true,
            isEditable: false
        )

        XCTAssertEqual(metadata.title, "FooView.swift")
        XCTAssertEqual(metadata.subtitle, "Sources/Feature")
        XCTAssertEqual(metadata.languageLabel, "Swift")
        XCTAssertEqual(
            metadata.badges,
            [.preview, .pinned, .dirty, .readOnly]
        )
    }

    func testBuildFallsBackToExtensionAndOmitsSubtitleForProjectRootFile() {
        let metadata = EditorTitleMetadata.build(
            fileURL: URL(fileURLWithPath: "/tmp/workspace/README.mdx"),
            projectRootPath: "/tmp/workspace",
            fileName: "README.mdx",
            fileExtension: "mdx",
            detectedLanguageName: nil,
            isPreview: false,
            isPinned: false,
            isDirty: false,
            isEditable: true
        )

        XCTAssertEqual(metadata.title, "README.mdx")
        XCTAssertNil(metadata.subtitle)
        XCTAssertEqual(metadata.languageLabel, "MDX")
        XCTAssertTrue(metadata.badges.isEmpty)
    }
}
#endif
