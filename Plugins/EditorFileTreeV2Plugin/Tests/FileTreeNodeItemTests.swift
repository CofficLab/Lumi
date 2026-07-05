import XCTest
@testable import EditorFileTreeV2Plugin

final class FileTreeNodeItemTests: XCTestCase {

    // MARK: - Basic Properties

    func testInitSetsProperties() {
        let url = URL(fileURLWithPath: "/tmp/test/main.swift")
        let item = FileTreeNodeItem(
            url: url, depth: 2, isDirectory: false,
            isExpanded: false, projectRootPath: "/tmp/test"
        )

        XCTAssertEqual(item.url, url)
        XCTAssertEqual(item.depth, 2)
        XCTAssertFalse(item.isDirectory)
        XCTAssertFalse(item.isExpanded)
        XCTAssertEqual(item.fileName, "main.swift")
        XCTAssertEqual(item.projectRootPath, "/tmp/test")
    }

    // MARK: - iconMetadata

    func testIconMetadataFromURL() {
        let url = URL(fileURLWithPath: "/root/Sources/main.swift")
        let item = FileTreeNodeItem(
            url: url, depth: 1, isDirectory: false,
            isExpanded: false, projectRootPath: "/root"
        )

        XCTAssertEqual(item.iconMetadata.fileName, "main.swift")
        XCTAssertEqual(item.iconMetadata.fileExtension, "swift")
        XCTAssertFalse(item.iconMetadata.isDirectory)
        XCTAssertFalse(item.iconMetadata.isSwiftPackageDirectory)
    }

    func testIsSwiftPackageDirectory() {
        let root = try! TestDirHelper.createSampleProject()
        defer { TestDirHelper.cleanup(root) }

        let item = FileTreeNodeItem(
            url: root, depth: 0, isDirectory: true,
            isExpanded: true, projectRootPath: root.path
        )

        XCTAssertTrue(item.iconMetadata.isSwiftPackageDirectory)
    }

    // MARK: - gitRelativePath

    func testGitRelativePathForChild() {
        let item = FileTreeNodeItem(
            url: URL(fileURLWithPath: "/root/Sources/main.swift"),
            depth: 2, isDirectory: false, isExpanded: false,
            projectRootPath: "/root"
        )
        XCTAssertEqual(item.gitRelativePath, "Sources/main.swift")
    }

    func testGitRelativePathForRoot() {
        let item = FileTreeNodeItem(
            url: URL(fileURLWithPath: "/root"),
            depth: 0, isDirectory: true, isExpanded: true,
            projectRootPath: "/root"
        )
        XCTAssertEqual(item.gitRelativePath, "")
    }

    // MARK: - Identifiable

    func testIdEqualsURL() {
        let url = URL(fileURLWithPath: "/tmp/foo")
        let item = FileTreeNodeItem(
            url: url, depth: 0, isDirectory: true,
            isExpanded: true, projectRootPath: "/tmp"
        )
        XCTAssertEqual(item.id, url)
    }

    // MARK: - Hashable / Equatable

    func testEqualityIgnoresIsDirectory() {
        let url = URL(fileURLWithPath: "/tmp/x")
        let lhs = FileTreeNodeItem(url: url, depth: 0, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        let rhs = FileTreeNodeItem(url: url, depth: 0, isDirectory: false, isExpanded: true, projectRootPath: "/tmp")
        XCTAssertEqual(lhs, rhs, "isDirectory is intentionally ignored for identity")
    }

    func testEqualityDistinguishesDepth() {
        let url = URL(fileURLWithPath: "/tmp/x")
        let shallow = FileTreeNodeItem(url: url, depth: 0, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        let deep = FileTreeNodeItem(url: url, depth: 1, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        XCTAssertNotEqual(shallow, deep)
    }

    func testEqualityDistinguishesIsExpanded() {
        let url = URL(fileURLWithPath: "/tmp/x")
        let collapsed = FileTreeNodeItem(url: url, depth: 0, isDirectory: true, isExpanded: false, projectRootPath: "/tmp")
        let expanded = FileTreeNodeItem(url: url, depth: 0, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        XCTAssertNotEqual(collapsed, expanded)
    }

    func testHashMatchesEquality() {
        let url = URL(fileURLWithPath: "/tmp/x")
        let a = FileTreeNodeItem(url: url, depth: 0, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        let b = FileTreeNodeItem(url: url, depth: 0, isDirectory: false, isExpanded: true, projectRootPath: "/tmp")
        XCTAssertEqual(a.hashValue, b.hashValue, "equal items must have equal hashValues")
    }

    func testHashDiffersWhenNotEqual() {
        let url = URL(fileURLWithPath: "/tmp/x")
        let a = FileTreeNodeItem(url: url, depth: 0, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        let b = FileTreeNodeItem(url: url, depth: 1, isDirectory: true, isExpanded: true, projectRootPath: "/tmp")
        XCTAssertNotEqual(a.hashValue, b.hashValue)
    }

    // MARK: - FileTreeIconMetadata

    func testIconMetadataEquality() {
        let a = FileTreeIconMetadata(fileName: "a", fileExtension: "swift", isDirectory: false, isSwiftPackageDirectory: false)
        let b = FileTreeIconMetadata(fileName: "a", fileExtension: "swift", isDirectory: false, isSwiftPackageDirectory: false)
        XCTAssertEqual(a.fileName, b.fileName)
        XCTAssertEqual(a.fileExtension, b.fileExtension)
        XCTAssertEqual(a.isDirectory, b.isDirectory)
        XCTAssertEqual(a.isSwiftPackageDirectory, b.isSwiftPackageDirectory)
    }
}
