import Testing
import Foundation
@testable import DiskManagerPlugin

/// Unit tests for pure-logic disk models: file-type classification, the top-N
/// MaxHeap, disk-usage percentage, and safety-level ordering.
@Suite struct FileTypeTests {

    @Test func classifiesImages() {
        #expect(LargeFileEntry.FileType.from(extension: "jpg") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "PNG") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "heic") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "webp") == .image)
    }

    @Test func classifiesVideos() {
        #expect(LargeFileEntry.FileType.from(extension: "mp4") == .video)
        #expect(LargeFileEntry.FileType.from(extension: "mkv") == .video)
    }

    @Test func classifiesAudio() {
        #expect(LargeFileEntry.FileType.from(extension: "mp3") == .audio)
        #expect(LargeFileEntry.FileType.from(extension: "flac") == .audio)
    }

    @Test func classifiesArchives() {
        #expect(LargeFileEntry.FileType.from(extension: "zip") == .archive)
        #expect(LargeFileEntry.FileType.from(extension: "gz") == .archive)
        #expect(LargeFileEntry.FileType.from(extension: "7z") == .archive)
    }

    @Test func classifiesCode() {
        #expect(LargeFileEntry.FileType.from(extension: "swift") == .code)
        #expect(LargeFileEntry.FileType.from(extension: "py") == .code)
        #expect(LargeFileEntry.FileType.from(extension: "json") == .code)
    }

    @Test func classifiesDocuments() {
        #expect(LargeFileEntry.FileType.from(extension: "pdf") == .document)
        #expect(LargeFileEntry.FileType.from(extension: "docx") == .document)
        #expect(LargeFileEntry.FileType.from(extension: "txt") == .document)
    }

    @Test func classifiesUnknownAsOther() {
        #expect(LargeFileEntry.FileType.from(extension: "xyz") == .other)
        #expect(LargeFileEntry.FileType.from(extension: "") == .other)
    }

    @Test func classificationIsCaseInsensitive() {
        #expect(LargeFileEntry.FileType.from(extension: "JPG") == .image)
        #expect(LargeFileEntry.FileType.from(extension: "Swift") == .code)
    }
}

@Suite struct MaxHeapTests {

    @Test func keepsTopNCapacity() {
        var heap = MaxHeap<Int>(capacity: 3)
        for n in [1, 2, 3, 4, 5] { heap.insert(n) }
        #expect(heap.elements == [5, 4, 3])
    }

    @Test func returnsDescendingOrder() {
        var heap = MaxHeap<Int>(capacity: 5)
        for n in [3, 1, 4, 1, 5, 9, 2] { heap.insert(n) }
        #expect(heap.elements == heap.elements.sorted(by: >))
        #expect(heap.elements.first == 9)
    }

    @Test func ignoresElementsBelowCurrentMinWhenFull() {
        var heap = MaxHeap<Int>(capacity: 2)
        heap.insert(10); heap.insert(20)
        heap.insert(5)  // below current min (10), should be ignored
        #expect(heap.elements == [20, 10])
    }

    @Test func acceptsLargerElementWhenFull() {
        var heap = MaxHeap<Int>(capacity: 2)
        heap.insert(10); heap.insert(20)
        heap.insert(30)  // above current min (10), evicts 10
        #expect(heap.elements == [30, 20])
    }

    @Test func emptyHeapProducesEmptyElements() {
        let heap = MaxHeap<Int>(capacity: 3)
        #expect(heap.elements.isEmpty)
    }

    @Test func handlesDuplicateInserts() {
        var heap = MaxHeap<Int>(capacity: 3)
        for n in [5, 5, 5, 5] { heap.insert(n) }
        #expect(heap.elements == [5, 5, 5])
    }
}

@Suite struct DiskUsageTests {

    @Test func usedPercentageComputesFraction() {
        let usage = DiskUsage(total: 100, used: 25, available: 75)
        #expect(usage.usedPercentage == 0.25)
    }

    @Test func usedPercentageZeroWhenTotalIsZero() {
        let usage = DiskUsage(total: 0, used: 10, available: 0)
        #expect(usage.usedPercentage == 0)
    }

    @Test func usedPercentageFull() {
        let usage = DiskUsage(total: 100, used: 100, available: 0)
        #expect(usage.usedPercentage == 1.0)
    }
}

@Suite struct SafetyLevelTests {

    @Test func orderingIsSafeLessThanMediumLessThanRisky() {
        #expect(CacheCategory.SafetyLevel.safe < .medium)
        #expect(CacheCategory.SafetyLevel.medium < .risky)
        #expect(CacheCategory.SafetyLevel.safe < .risky)
    }

    @Test func sortBySafetyLevelAscending() {
        let levels: [CacheCategory.SafetyLevel] = [.risky, .safe, .medium]
        #expect(levels.sorted() == [.safe, .medium, .risky])
    }
}
