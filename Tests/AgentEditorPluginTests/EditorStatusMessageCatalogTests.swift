#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorStatusMessageCatalogTests: XCTestCase {
    func testExternalFileChangedOnDiskUsesProjectSpecificCopy() {
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(
            fileName: "project.pbxproj",
            isProjectFile: true
        )

        XCTAssertTrue(message.contains("Prefer the Xcode version"))
        XCTAssertTrue(message.contains("Lumi version"))
    }

    func testExternalFileChangedOnDiskIncludesFileNameForRegularFiles() {
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(
            fileName: "Info.plist",
            isProjectFile: false
        )

        XCTAssertEqual(message, "Info.plist changed on disk. Reload or keep the editor version.")
    }
}
#endif
