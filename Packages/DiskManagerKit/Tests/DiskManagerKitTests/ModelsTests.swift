import Foundation
import Testing
@testable import DiskManagerKit

// MARK: - DiskUsage Tests

struct DiskUsageTests {
    @Test
    func usedPercentageCalculatesCorrectly() {
        let usage = DiskUsage(total: 100, used: 50, available: 50)
        #expect(usage.usedPercentage == 0.5)
    }

    @Test
    func usedPercentageHandlesZeroTotal() {
        let usage = DiskUsage(total: 0, used: 0, available: 0)
        #expect(usage.usedPercentage == 0)
    }

    @Test
    func usedPercentageHandlesFullDisk() {
        let usage = DiskUsage(total: 1000, used: 1000, available: 0)
        #expect(usage.usedPercentage == 1.0)
    }

    @Test
    func usedPercentageHandlesEmptyDisk() {
        let usage = DiskUsage(total: 1000, used: 0, available: 1000)
        #expect(usage.usedPercentage == 0.0)
    }

    @Test
    func codableRoundTrip() throws {
        let original = DiskUsage(total: 500_000_000_000, used: 300_000_000_000, available: 200_000_000_000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiskUsage.self, from: data)
        #expect(decoded.total == original.total)
        #expect(decoded.used == original.used)
        #expect(decoded.available == original.available)
    }
}

// MARK: - DirectoryEntry Tests

struct DirectoryEntryTests {
    @Test
    func depthCalculation() {
        let entry = makeEntry(path: "/Users/test/Documents/project")
        #expect(entry.depth == 5)
    }

    @Test
    func isScannedWhenChildrenPresent() {
        var entry = makeEntry(path: "/test")
        #expect(entry.isScanned == false)

        entry.children = []
        #expect(entry.isScanned == true)
    }

    @Test
    func hashableAndIdentifiable() {
        let a = makeEntry(id: "a", path: "/a")
        let b = makeEntry(id: "b", path: "/b")
        let a2 = makeEntry(id: "a", path: "/a")

        #expect(a != b)
        #expect(a == a2)

        var set = Set<DirectoryEntry>()
        set.insert(a)
        set.insert(a2)
        #expect(set.count == 1)
    }

    @Test
    func codableRoundTrip() throws {
        let child = makeEntry(id: "child", name: "child", path: "/root/child", size: 100)
        let parent = makeEntry(id: "parent", name: "root", path: "/root", size: 100, children: [child])

        let data = try JSONEncoder().encode(parent)
        let decoded = try JSONDecoder().decode(DirectoryEntry.self, from: data)

        #expect(decoded.id == "parent")
        #expect(decoded.name == "root")
        #expect(decoded.children?.count == 1)
        #expect(decoded.children?.first?.name == "child")
    }
}

// MARK: - LargeFileEntry Tests

struct LargeFileEntryTests {
    @Test
    func comparableBySize() {
        let small = makeLargeFile(size: 100)
        let large = makeLargeFile(size: 1000)

        #expect(small < large)
        #expect(!(large < small))
    }

    @Test
    func fileTypeFromExtension() {
        #expect(LargeFileEntry.FileType.from(extension: "jpg") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "PNG") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "mp4") == .video)
        #expect(LargeFileEntry.FileType.from(extension: "mp3") == .audio)
        #expect(LargeFileEntry.FileType.from(extension: "zip") == .archive)
        #expect(LargeFileEntry.FileType.from(extension: "swift") == .code)
        #expect(LargeFileEntry.FileType.from(extension: "pdf") == .document)
        #expect(LargeFileEntry.FileType.from(extension: "xyz") == .other)
    }

    @Test
    func fileTypeIsCaseInsensitive() {
        #expect(LargeFileEntry.FileType.from(extension: "JPG") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "Swift") == .code)
        #expect(LargeFileEntry.FileType.from(extension: "ZIP") == .archive)
    }

    @Test
    func codableRoundTrip() throws {
        let original = makeLargeFile(size: 500_000_000, fileType: .video)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LargeFileEntry.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.size == original.size)
        #expect(decoded.fileType == .video)
    }
}

// MARK: - ScanResult Tests

struct ScanResultTests {
    @Test
    func initialization() {
        let result = ScanResult(
            entries: [],
            largeFiles: [],
            totalSize: 1024,
            totalFiles: 5,
            scanDuration: 1.5,
            scannedAt: Date()
        )

        #expect(result.totalSize == 1024)
        #expect(result.totalFiles == 5)
        #expect(result.scanDuration == 1.5)
        #expect(result.entries.isEmpty)
        #expect(result.largeFiles.isEmpty)
    }
}

// MARK: - ScanProgress Tests

struct ScanProgressTests {
    @Test
    func durationAndFilesPerSecond() {
        let start = Date().addingTimeInterval(-2.0)
        let progress = ScanProgress(
            path: "/test",
            currentPath: "/test/file",
            scannedFiles: 100,
            scannedDirectories: 10,
            scannedBytes: 5000,
            startTime: start
        )

        #expect(progress.duration >= 1.9)
        #expect(progress.filesPerSecond > 0)
    }
}

// MARK: - CacheCategory Tests

struct CacheCategoryTests {
    @Test
    func totalSizeAndFileCountAggregation() {
        let paths = [
            makeCachePath(size: 100, fileCount: 5),
            makeCachePath(size: 200, fileCount: 10),
            makeCachePath(size: 300, fileCount: 15),
        ]
        let category = CacheCategory(
            id: "test",
            name: "Test",
            description: "Test category",
            icon: "folder",
            paths: paths,
            safetyLevel: .safe
        )

        #expect(category.totalSize == 600)
        #expect(category.fileCount == 30)
    }

    @Test
    func safetyLevelComparable() {
        #expect(CacheCategory.SafetyLevel.safe < .medium)
        #expect(CacheCategory.SafetyLevel.medium < .risky)
        #expect(!(CacheCategory.SafetyLevel.risky < .safe))
    }

    @Test
    func safetyLevelColors() {
        #expect(CacheCategory.SafetyLevel.safe.color == "green")
        #expect(CacheCategory.SafetyLevel.medium.color == "orange")
        #expect(CacheCategory.SafetyLevel.risky.color == "red")
    }

    @Test
    func emptyPathsCategory() {
        let category = CacheCategory(
            id: "empty",
            name: "Empty",
            description: "No paths",
            icon: "folder",
            paths: [],
            safetyLevel: .safe
        )

        #expect(category.totalSize == 0)
        #expect(category.fileCount == 0)
    }
}

// MARK: - CachePath Tests

struct CachePathTests {
    @Test
    func equalityByID() {
        let id = UUID()
        let a = CachePath(id: id, path: "/a", name: "A", description: "", size: 10, fileCount: 1, canDelete: true)
        let b = CachePath(id: id, path: "/b", name: "B", description: "", size: 20, fileCount: 2, canDelete: false)

        #expect(a == b) // Same ID
    }

    @Test
    func hashableInSet() {
        let a = CachePath(path: "/a", name: "A", description: "", size: 10, fileCount: 1, canDelete: true)
        let b = CachePath(path: "/a", name: "A", description: "", size: 10, fileCount: 1, canDelete: true)

        var set = Set<CachePath>()
        set.insert(a)
        set.insert(b)
        #expect(set.count == 2) // Different UUIDs
    }
}

// MARK: - ProjectInfo Tests

struct ProjectInfoTests {
    @Test
    func totalSizeAggregation() {
        let project = ProjectInfo(
            name: "TestProject",
            path: "/test",
            type: .node,
            cleanableItems: [
                CleanableItem(path: "/test/node_modules", name: "node_modules", size: 500),
                CleanableItem(path: "/test/dist", name: "dist", size: 300),
            ]
        )

        #expect(project.totalSize == 800)
    }

    @Test
    func projectTypeDisplayNames() {
        #expect(ProjectInfo.ProjectType.node.displayName == "Node.js")
        #expect(ProjectInfo.ProjectType.rust.displayName == "Rust")
        #expect(ProjectInfo.ProjectType.swift.displayName == "Swift/Xcode")
        #expect(ProjectInfo.ProjectType.python.displayName == "Python")
        #expect(ProjectInfo.ProjectType.generic.displayName == "Generic")
    }

    @Test
    func projectTypeIcons() {
        #expect(ProjectInfo.ProjectType.node.icon == "hexagon")
        #expect(ProjectInfo.ProjectType.rust.icon == "gearshape")
        #expect(ProjectInfo.ProjectType.swift.icon == "swift")
        #expect(ProjectInfo.ProjectType.python.icon == "ladybug")
        #expect(ProjectInfo.ProjectType.generic.icon == "folder")
    }

    @Test
    func allCasesCount() {
        #expect(ProjectInfo.ProjectType.allCases.count == 5)
    }

    @Test
    func emptyCleanableItems() {
        let project = ProjectInfo(
            name: "Empty",
            path: "/empty",
            type: .generic,
            cleanableItems: []
        )

        #expect(project.totalSize == 0)
    }
}

// MARK: - XcodeCleanCategory Tests

struct XcodeCleanCategoryTests {
    @Test
    func allCasesAreIdentifiable() {
        for category in XcodeCleanCategory.allCases {
            #expect(!category.id.isEmpty)
            #expect(category.id == category.rawValue)
        }
    }

    @Test
    func displayNameNotEmpty() {
        for category in XcodeCleanCategory.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    @Test
    func iconNameNotEmpty() {
        for category in XcodeCleanCategory.allCases {
            #expect(!category.iconName.isEmpty)
        }
    }

    @Test
    func descriptionNotEmpty() {
        for category in XcodeCleanCategory.allCases {
            #expect(!category.description.isEmpty)
        }
    }

    @Test
    func allCasesCount() {
        #expect(XcodeCleanCategory.allCases.count == 7)
    }
}

// MARK: - XcodeCleanItem Tests

struct XcodeCleanItemTests {
    @Test
    func initialization() {
        let item = XcodeCleanItem(
            name: "MyApp",
            path: URL(fileURLWithPath: "/tmp/MyApp"),
            size: 1000,
            category: .derivedData,
            modificationDate: Date(),
            isSelected: true,
            version: "15.0"
        )

        #expect(item.name == "MyApp")
        #expect(item.size == 1000)
        #expect(item.category == .derivedData)
        #expect(item.isSelected == true)
        #expect(item.version == "15.0")
    }

    @Test
    func defaultValues() {
        let item = XcodeCleanItem(
            name: "Test",
            path: URL(fileURLWithPath: "/tmp"),
            size: 0,
            category: .logs,
            modificationDate: Date()
        )

        #expect(item.isSelected == false)
        #expect(item.version == nil)
    }

    @Test
    func equatableByReference() {
        // XcodeCleanItem has a default UUID, so two instances are never equal.
        // But same instance is always equal to itself.
        let a = XcodeCleanItem(name: "A", path: URL(fileURLWithPath: "/a"), size: 10, category: .logs, modificationDate: Date())
        #expect(a == a)
    }
}

// MARK: - CleanupResult Tests

struct CleanupResultTests {
    @Test
    func initialization() {
        let result = CleanupResult(
            categories: [],
            totalSize: 5000,
            totalFiles: 42,
            cleanedAt: Date()
        )

        #expect(result.totalSize == 5000)
        #expect(result.totalFiles == 42)
        #expect(result.categories.isEmpty)
    }
}

// MARK: - Helpers

private func makeEntry(
    id: String = UUID().uuidString,
    name: String = "test",
    path: String = "/test",
    size: Int64 = 0,
    isDirectory: Bool = true,
    children: [DirectoryEntry]? = nil
) -> DirectoryEntry {
    DirectoryEntry(
        id: id,
        name: name,
        path: path,
        size: size,
        isDirectory: isDirectory,
        lastAccessed: Date(),
        modificationDate: Date(),
        children: children
    )
}

private func makeLargeFile(
    id: String = UUID().uuidString,
    name: String = "file.mp4",
    path: String = "/test/file.mp4",
    size: Int64 = 1000,
    fileType: LargeFileEntry.FileType = .other
) -> LargeFileEntry {
    LargeFileEntry(
        id: id,
        name: name,
        path: path,
        size: size,
        modificationDate: Date(),
        fileType: fileType
    )
}

private func makeCachePath(
    path: String = "/cache/item",
    name: String = "item",
    size: Int64 = 0,
    fileCount: Int = 0
) -> CachePath {
    CachePath(
        path: path,
        name: name,
        description: "",
        size: size,
        fileCount: fileCount,
        canDelete: true
    )
}
