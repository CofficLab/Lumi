import Foundation
import Testing
@testable import DiskManagerKit

// MARK: - MaxHeap Tests

struct MaxHeapTests {
    @Test
    func maintainsTopNElements() {
        var heap = MaxHeap<Int>(capacity: 3)

        heap.insert(1)
        heap.insert(5)
        heap.insert(3)
        heap.insert(10)
        heap.insert(2)

        let elements = heap.elements
        #expect(elements.count == 3)
        #expect(elements == [10, 5, 3])
    }

    @Test
    func emptyHeapReturnsEmpty() {
        let heap = MaxHeap<Int>(capacity: 5)
        #expect(heap.elements.isEmpty)
    }

    @Test
    func capacityOneKeepsLargest() {
        var heap = MaxHeap<Int>(capacity: 1)

        heap.insert(5)
        heap.insert(10)
        heap.insert(3)

        #expect(heap.elements == [10])
    }

    @Test
    func fewerThanCapacityKeepsAll() {
        var heap = MaxHeap<Int>(capacity: 10)

        heap.insert(3)
        heap.insert(1)
        heap.insert(5)

        let elements = heap.elements
        #expect(elements.count == 3)
        #expect(elements == [5, 3, 1])
    }

    @Test
    func duplicateElements() {
        var heap = MaxHeap<Int>(capacity: 3)

        heap.insert(5)
        heap.insert(5)
        heap.insert(5)

        let elements = heap.elements
        #expect(elements.count == 3)
        #expect(elements.allSatisfy { $0 == 5 })
    }

    @Test
    func elementsReturnedInDescendingOrder() {
        var heap = MaxHeap<Int>(capacity: 5)

        heap.insert(1)
        heap.insert(3)
        heap.insert(5)
        heap.insert(2)
        heap.insert(4)

        let elements = heap.elements
        #expect(elements == [5, 4, 3, 2, 1])
    }

    @Test
    func worksWithLargeFileEntry() {
        var heap = MaxHeap<LargeFileEntry>(capacity: 2)

        let small = LargeFileEntry(id: "1", name: "small.txt", path: "/a", size: 100, modificationDate: Date(), fileType: .other)
        let medium = LargeFileEntry(id: "2", name: "medium.mp4", path: "/b", size: 500, modificationDate: Date(), fileType: .video)
        let large = LargeFileEntry(id: "3", name: "large.iso", path: "/c", size: 1000, modificationDate: Date(), fileType: .other)

        heap.insert(small)
        heap.insert(medium)
        heap.insert(large)

        let elements = heap.elements
        #expect(elements.count == 2)
        #expect(elements[0].size == 1000)
        #expect(elements[1].size == 500)
    }
}

// MARK: - ScanCacheService Tests

struct ScanCacheServiceTests {
    @Test
    func defaultCacheDirectoryUsesCachesDirectoryWhenAvailable() {
        let cachesDirectory = URL(fileURLWithPath: "/tmp/Caches", isDirectory: true)
        let temporaryDirectory = URL(fileURLWithPath: "/tmp/Temporary", isDirectory: true)

        let url = ScanCacheService.defaultCacheDirectory(
            cachesDirectory: cachesDirectory,
            temporaryDirectory: temporaryDirectory
        )

        #expect(url.path == "/tmp/Caches/DiskManagerKit/ScanCache")
    }

    @Test
    func defaultCacheDirectoryFallsBackToTemporaryDirectory() {
        let temporaryDirectory = URL(fileURLWithPath: "/tmp/Temporary", isDirectory: true)

        let url = ScanCacheService.defaultCacheDirectory(
            cachesDirectory: nil,
            temporaryDirectory: temporaryDirectory
        )

        #expect(url.path == "/tmp/Temporary/DiskManagerKit/ScanCache")
    }

    @Test
    func initWithCustomDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskManagerKitTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        _ = ScanCacheService(cacheDirectory: tmpDir)
        #expect(FileManager.default.fileExists(atPath: tmpDir.path))
    }

    @Test
    func saveAndLoadCycle() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskManagerKitTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let service = ScanCacheService(cacheDirectory: tmpDir)

        let result = ScanResult(
            entries: [],
            largeFiles: [],
            totalSize: 12345,
            totalFiles: 10,
            scanDuration: 1.0,
            scannedAt: Date()
        )

        await service.save(result, for: "/test/path")

        // Wait a bit for async write
        try await Task.sleep(nanoseconds: 200_000_000)

        let loaded = await service.load(for: "/test/path")
        #expect(loaded != nil)
        #expect(loaded?.totalSize == 12345)
        #expect(loaded?.totalFiles == 10)
    }

    @Test
    func loadReturnsNilForMissingCache() async {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskManagerKitTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let service = ScanCacheService(cacheDirectory: tmpDir)
        let loaded = await service.load(for: "/nonexistent/path")
        #expect(loaded == nil)
    }

    @Test
    func clearCacheRemovesAll() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskManagerKitTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let service = ScanCacheService(cacheDirectory: tmpDir)

        let result = ScanResult(
            entries: [],
            largeFiles: [],
            totalSize: 100,
            totalFiles: 1,
            scanDuration: 0.1,
            scannedAt: Date()
        )

        await service.save(result, for: "/some/path")
        try await Task.sleep(nanoseconds: 200_000_000)

        await service.clearCache()

        let loaded = await service.load(for: "/some/path")
        #expect(loaded == nil)
    }
}

// MARK: - DiskService Tests (non-filesystem)

struct DiskServiceTests {
    @Test
    func isSingleton() {
        let a = DiskService.shared
        let b = DiskService.shared
        #expect(a === b)
    }

    @Test
    func getDiskUsageReturnsNonNil() async {
        let usage = await DiskService.shared.getDiskUsage()
        #expect(usage != nil)
        #expect(usage!.total > 0)
        #expect(usage!.available > 0)
        #expect(usage!.used > 0)
        #expect(usage!.used + usage!.available == usage!.total)
    }
}

// MARK: - CacheCleanerService Tests

struct CacheCleanerServiceTests {
    @Test
    func cleanupThrowsWhenASelectedPathCannotBeRemoved() async throws {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskManagerKitMissing-\(UUID().uuidString)")
            .path
        let item = CachePath(
            path: missingPath,
            name: "missing",
            description: missingPath,
            size: 1024,
            fileCount: 1,
            canDelete: true
        )

        await #expect(throws: CacheCleanupError.self) {
            _ = try await CacheCleanerService.shared.cleanup(paths: [item])
        }
    }

    @Test
    func cleanupReturnsFreedSpaceForRemovedPaths() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskManagerKitCleanup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let item = CachePath(
            path: directory.path,
            name: directory.lastPathComponent,
            description: directory.path,
            size: 2048,
            fileCount: 1,
            canDelete: true
        )

        let freedSpace = try await CacheCleanerService.shared.cleanup(paths: [item])

        #expect(freedSpace == 2048)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }
}

// MARK: - ProgressCounter Tests

struct ProgressCounterTests {
    @Test
    func initialCountsAreZero() {
        let counter = ProgressCounter()
        let (files, size) = counter.current
        #expect(files == 0)
        #expect(size == 0)
    }

    @Test
    func incrementUpdatesCounts() {
        let counter = ProgressCounter()
        counter.increment(size: 100)
        counter.increment(size: 200)

        let (files, size) = counter.current
        #expect(files == 2)
        #expect(size == 300)
    }

    @Test
    func concurrentIncrementsAreThreadSafe() async {
        let counter = ProgressCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    counter.increment(size: 1)
                }
            }
        }

        let (files, _) = counter.current
        #expect(files == 100)
    }
}
