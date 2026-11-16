import Foundation
import Testing
@testable import PluginDiskManager

/// Regression coverage for #849: the five Disk Manager scan interfaces hid the
/// only Stop control while scanning. The control bar (whose Stop branch calls
/// `stopScan()`) must stay reachable during a scan even before any results
/// exist, switch back to Start/Refresh once idle with results, and hide only
/// when idle and empty.
@Suite struct ScanControlBarVisibilityTests {

    @Test func scanningKeepsControlBarVisibleWithoutResults() {
        // 核心回归：扫描进行中、结果尚未产生时，Stop 入口必须可达。
        #expect(ScanControlBarVisibility.isVisible(isScanning: true, hasResults: false))
    }

    @Test func scanningKeepsControlBarVisibleWithResults() {
        #expect(ScanControlBarVisibility.isVisible(isScanning: true, hasResults: true))
    }

    @Test func idleWithResultsShowsControlBar() {
        #expect(ScanControlBarVisibility.isVisible(isScanning: false, hasResults: true))
    }

    @Test func idleWithoutResultsHidesControlBar() {
        #expect(!ScanControlBarVisibility.isVisible(isScanning: false, hasResults: false))
    }
}

/// Each scan interface's ViewModel must drive its control-bar visibility from
/// its real scanning flag and results collection, so the Stop branch stays
/// reachable during a scan (including Large Files, which clears results at
/// scan start).
@MainActor
@Suite struct ScanControlBarViewModelTests {

    @Test func cacheCleanerControlBarStaysVisibleWhileScanning() {
        let viewModel = CacheCleanerViewModel()
        viewModel.isScanning = false
        viewModel.categories = []
        #expect(viewModel.isScanControlBarVisible == false)

        viewModel.isScanning = true
        #expect(viewModel.isScanControlBarVisible == true)

        viewModel.isScanning = false
        viewModel.categories = [CacheCategory(id: "c", name: "C", description: "", icon: "", paths: [], safetyLevel: .safe)]
        #expect(viewModel.isScanControlBarVisible == true)
    }

    @Test func directoryTreeControlBarStaysVisibleWhileScanning() {
        let viewModel = DirectoryTreeViewModel()
        viewModel.isScanning = false
        viewModel.rootEntries = []
        #expect(viewModel.isScanControlBarVisible == false)

        viewModel.isScanning = true
        #expect(viewModel.isScanControlBarVisible == true)

        viewModel.isScanning = false
        viewModel.rootEntries = [DirectoryEntry(id: "d", name: "D", path: "/tmp/d", size: 0, isDirectory: true, lastAccessed: Date(), modificationDate: Date(), children: nil)]
        #expect(viewModel.isScanControlBarVisible == true)
    }

    @Test func largeFilesControlBarStaysVisibleWhileScanning() {
        let viewModel = LargeFilesViewModel()
        viewModel.isScanning = false
        viewModel.largeFiles = []
        #expect(viewModel.isScanControlBarVisible == false)

        // startScan() 会清空 largeFiles；扫描中即便结果为空也必须保留 Stop。
        viewModel.isScanning = true
        viewModel.largeFiles = []
        #expect(viewModel.isScanControlBarVisible == true)

        viewModel.isScanning = false
        viewModel.largeFiles = [LargeFileEntry(id: "f", name: "F", path: "/tmp/f", size: 1, modificationDate: Date(), fileType: .other)]
        #expect(viewModel.isScanControlBarVisible == true)
    }

    @Test func projectCleanerControlBarStaysVisibleWhileScanning() {
        let viewModel = ProjectCleanerViewModel()
        viewModel.isScanning = false
        viewModel.projects = []
        #expect(viewModel.isScanControlBarVisible == false)

        viewModel.isScanning = true
        #expect(viewModel.isScanControlBarVisible == true)

        viewModel.isScanning = false
        viewModel.projects = [ProjectInfo(name: "P", path: "/tmp/p", type: .generic, cleanableItems: [])]
        #expect(viewModel.isScanControlBarVisible == true)
    }

    @Test func xcodeCleanerControlBarStaysVisibleWhileScanning() {
        let viewModel = XcodeCleanerViewModel()
        viewModel.isScanning = false
        viewModel.itemsByCategory = [:]
        #expect(viewModel.isScanControlBarVisible == false)

        viewModel.isScanning = true
        #expect(viewModel.isScanControlBarVisible == true)

        viewModel.isScanning = false
        viewModel.itemsByCategory = [.derivedData: [XcodeCleanItem(name: "I", path: URL(fileURLWithPath: "/tmp/i"), size: 1, category: .derivedData, modificationDate: Date())]]
        #expect(viewModel.isScanControlBarVisible == true)
    }
}