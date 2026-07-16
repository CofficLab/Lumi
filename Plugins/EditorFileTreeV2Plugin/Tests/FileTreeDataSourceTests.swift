import XCTest
@testable import EditorFileTreeV2Plugin

@MainActor
final class FileTreeDataSourceTests: XCTestCase {
    var fileSystem: MockFileSystemReader!
    var store: MockExpandedPathStore!
    var dataSource: FileTreeDataSource!
    
    override func setUp() {
        super.setUp()
        fileSystem = MockFileSystemReader()
        store = MockExpandedPathStore()
        dataSource = FileTreeDataSource(
            fileSystemReader: fileSystem,
            expandedPathStore: store
        )
    }
    
    override func tearDown() {
        fileSystem = nil
        store = nil
        dataSource = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func testInitialItemsIsEmpty() {
        XCTAssertTrue(dataSource.items.isEmpty)
    }
    
    func testInitialProjectRootPathIsEmpty() {
        XCTAssertTrue(dataSource.projectRootPath.isEmpty)
    }
    
    // MARK: - Empty Project Root
    
    func testSetEmptyProjectRootKeepsItemsEmpty() {
        dataSource.setProjectRoot("")
        XCTAssertTrue(dataSource.items.isEmpty)
    }
    
    // MARK: - Root Node Expansion
    
    func testRootNodeAlwaysExpanded() {
        let root = URL(fileURLWithPath: "/project")
        fileSystem.markAsDirectory(root)

        dataSource.setProjectRoot("/project")

        XCTAssertEqual(dataSource.fileItems.count, 1)
        XCTAssertEqual(dataSource.fileItems[0].isExpanded, true)
        XCTAssertEqual(dataSource.fileItems[0].depth, 0)
    }

    func testNonRootNodeNotExpandedByDefault() {
        let root = URL(fileURLWithPath: "/project")
        let sources = URL(fileURLWithPath: "/project/Sources")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsDirectory(sources)
        fileSystem.registerDirectory(root, contents: [sources])

        dataSource.setProjectRoot("/project")

        XCTAssertEqual(dataSource.fileItems.count, 2)
        XCTAssertEqual(dataSource.fileItems[0].isExpanded, true) // root
        XCTAssertEqual(dataSource.fileItems[1].isExpanded, false) // Sources
    }
    
    // MARK: - Expanded Paths
    
    func testPreloadedExpandedPaths() {
        let root = URL(fileURLWithPath: "/project")
        let sources = URL(fileURLWithPath: "/project/Sources")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsDirectory(sources)
        fileSystem.registerDirectory(root, contents: [sources])
        
        store.addExpandedPath("/Sources", for: "/project")
        dataSource.setProjectRoot("/project")

        XCTAssertEqual(dataSource.fileItems.count, 2)
        XCTAssertEqual(dataSource.fileItems[0].isExpanded, true) // root
        XCTAssertEqual(dataSource.fileItems[1].isExpanded, true) // Sources
    }
    
    func testToggleExpansionAddsToStore() {
        let root = URL(fileURLWithPath: "/project")
        let sources = URL(fileURLWithPath: "/project/Sources")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsDirectory(sources)
        fileSystem.registerDirectory(root, contents: [sources])
        
        dataSource.setProjectRoot("/project")
        
        dataSource.toggleExpansion(at: sources)
        
        let paths = store.expandedPaths(for: "/project")
        XCTAssertTrue(paths.contains("/Sources"))
    }
    
    func testToggleCollapseRemovesFromStore() {
        let root = URL(fileURLWithPath: "/project")
        let sources = URL(fileURLWithPath: "/project/Sources")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsDirectory(sources)
        fileSystem.registerDirectory(root, contents: [sources])
        
        store.addExpandedPath("/Sources", for: "/project")
        dataSource.setProjectRoot("/project")
        
        dataSource.toggleExpansion(at: sources)
        
        let paths = store.expandedPaths(for: "/project")
        XCTAssertFalse(paths.contains("/Sources"))
    }
    
    // MARK: - Directory Listing
    
    func testLoadsDirectoryContents() {
        let root = URL(fileURLWithPath: "/project")
        let fileA = URL(fileURLWithPath: "/project/a.txt")
        let fileB = URL(fileURLWithPath: "/project/b.txt")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsFile(fileA)
        fileSystem.markAsFile(fileB)
        fileSystem.registerDirectory(root, contents: [fileA, fileB])
        
        dataSource.setProjectRoot("/project")

        XCTAssertEqual(dataSource.fileItems.count, 3) // root + 2 files
    }

    func testDirectoriesSortedBeforeFiles() {
        let root = URL(fileURLWithPath: "/project")
        let fileZ = URL(fileURLWithPath: "/project/z.txt")
        let dirA = URL(fileURLWithPath: "/project/a")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsFile(fileZ)
        fileSystem.markAsDirectory(dirA)
        fileSystem.registerDirectory(root, contents: [fileZ, dirA])

        dataSource.setProjectRoot("/project")

        XCTAssertEqual(dataSource.fileItems.count, 3)
        // dirA should come before fileZ (directories first, then alphabetical)
        XCTAssertEqual(dataSource.fileItems[1].url, dirA)
        XCTAssertEqual(dataSource.fileItems[2].url, fileZ)
    }
    
    // MARK: - Callbacks
    
    func testOnItemsChangedCalled() {
        var callbackItems: [CollectionItem]?

        dataSource.onItemsChanged = { items in
            callbackItems = items
        }

        let root = URL(fileURLWithPath: "/project")
        fileSystem.markAsDirectory(root)

        dataSource.setProjectRoot("/project")

        XCTAssertNotNil(callbackItems)
        // 回调收到完整 items（含 package header），这里只验证文件节点数
        XCTAssertEqual(callbackItems?.compactMap { $0.fileItem }.count, 1)
    }
    
    func testFullRefreshTriggersCallback() {
        let root = URL(fileURLWithPath: "/project")
        fileSystem.markAsDirectory(root)
        
        dataSource.setProjectRoot("/project")
        
        var callbackCalled = false
        dataSource.onItemsChanged = { _ in
            callbackCalled = true
        }
        
        dataSource.fullRefresh()
        
        XCTAssertTrue(callbackCalled)
    }
    
    // MARK: - Edge Cases
    
    func testToggleExpansionOnNonexistentItemDoesNothing() {
        let root = URL(fileURLWithPath: "/project")
        fileSystem.markAsDirectory(root)

        dataSource.setProjectRoot("/project")

        let fakeURL = URL(fileURLWithPath: "/nonexistent")
        dataSource.toggleExpansion(at: fakeURL)

        XCTAssertEqual(dataSource.fileItems.count, 1) // unchanged
    }

    func testToggleExpansionOnFileDoesNothing() {
        let root = URL(fileURLWithPath: "/project")
        let file = URL(fileURLWithPath: "/project/file.txt")
        fileSystem.markAsDirectory(root)
        fileSystem.markAsFile(file)
        fileSystem.registerDirectory(root, contents: [file])

        dataSource.setProjectRoot("/project")

        dataSource.toggleExpansion(at: file)

        XCTAssertEqual(dataSource.fileItems.count, 2) // unchanged
    }

    func testSetProjectRootClearsPreviousItems() {
        let root1 = URL(fileURLWithPath: "/project1")
        let root2 = URL(fileURLWithPath: "/project2")
        fileSystem.markAsDirectory(root1)
        fileSystem.markAsDirectory(root2)

        dataSource.setProjectRoot("/project1")
        XCTAssertEqual(dataSource.fileItems.count, 1)

        dataSource.setProjectRoot("/project2")
        XCTAssertEqual(dataSource.fileItems.count, 1)
        XCTAssertEqual(dataSource.fileItems[0].url, root2)
    }
}
