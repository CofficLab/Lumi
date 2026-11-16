import Foundation
import Testing
@testable import PluginDiskManager

/// Regression coverage for #1222: the Xcode Cleaner footer read `selectedSize`
/// twice and `totalSize` once per body evaluation, and each computed property
/// flattened/filtered/reduced the whole result set again; category headers
/// separately filtered/reduced their items. The aggregates must be a snapshot
/// rebuilt once per `itemsByCategory` update and shared across the views, so
/// reading them many times within one update does no extra traversal.
@MainActor
@Suite struct XcodeCleanerSummaryTests {

    private func item(_ name: String, size: Int64, category: XcodeCleanCategory, selected: Bool) -> XcodeCleanItem {
        XcodeCleanItem(
            name: name,
            path: URL(fileURLWithPath: "/tmp/\(name)"),
            size: size,
            category: category,
            modificationDate: Date(),
            isSelected: selected
        )
    }

    @Test func summaryMatchesItemsAfterPublication() {
        let viewModel = XcodeCleanerViewModel()
        let derived = [
            item("a", size: 100, category: .derivedData, selected: true),
            item("b", size: 200, category: .derivedData, selected: false),
        ]
        let logs = [item("c", size: 30, category: .logs, selected: true)]
        viewModel.itemsByCategory = [.derivedData: derived, .logs: logs]

        #expect(viewModel.totalSize == 330)
        #expect(viewModel.selectedSize == 130)
        #expect(viewModel.selectedCount == 2)
        #expect(viewModel.categorySummary[.derivedData] == XcodeCategorySummary(size: 300, selectedSize: 100, selectedCount: 1, totalCount: 2))
        #expect(viewModel.categorySummary[.logs] == XcodeCategorySummary(size: 30, selectedSize: 30, selectedCount: 1, totalCount: 1))
    }

    @Test func summaryIsRebuiltOncePerUpdateNotPerRead() {
        let viewModel = XcodeCleanerViewModel()
        viewModel.itemsByCategory = [.derivedData: [item("a", size: 100, category: .derivedData, selected: true)]]

        // 一次发布 → 一次重算。
        let baseline = viewModel.summaryRebuildCount
        #expect(baseline == 1)

        // 模拟单次 footer body 多次读取聚合：不得触发额外重算。
        for _ in 0..<50 {
            _ = viewModel.selectedSize
            _ = viewModel.totalSize
            _ = viewModel.selectedCount
            _ = viewModel.categorySummary[.derivedData]
        }
        #expect(viewModel.summaryRebuildCount == baseline)
    }

    @Test func toggleUpdatesSummaryByExactlyTheChangedItem() {
        let viewModel = XcodeCleanerViewModel()
        let target = item("a", size: 100, category: .derivedData, selected: false)
        viewModel.itemsByCategory = [.derivedData: [target, item("b", size: 200, category: .derivedData, selected: true)]]

        let rebuildsBefore = viewModel.summaryRebuildCount
        #expect(viewModel.selectedSize == 200)
        #expect(viewModel.selectedCount == 1)

        viewModel.toggleSelection(for: target)

        // 单行切换只触发一次重算，且只改变该行的贡献。
        #expect(viewModel.summaryRebuildCount == rebuildsBefore + 1)
        #expect(viewModel.selectedSize == 300)
        #expect(viewModel.selectedCount == 2)
        #expect(viewModel.totalSize == 300)
        #expect(viewModel.categorySummary[.derivedData]?.selectedCount == 2)
    }

    @Test func selectAllAndDeselectAllRefreshCategorySummary() {
        let viewModel = XcodeCleanerViewModel()
        viewModel.itemsByCategory = [.logs: [
            item("a", size: 10, category: .logs, selected: false),
            item("b", size: 20, category: .logs, selected: true),
        ]]

        viewModel.selectAll(in: .logs)
        #expect(viewModel.categorySummary[.logs] == XcodeCategorySummary(size: 30, selectedSize: 30, selectedCount: 2, totalCount: 2))
        #expect(viewModel.selectedSize == 30)
        #expect(viewModel.selectedCount == 2)

        viewModel.deselectAll(in: .logs)
        #expect(viewModel.categorySummary[.logs] == XcodeCategorySummary(size: 30, selectedSize: 0, selectedCount: 0, totalCount: 2))
        #expect(viewModel.selectedSize == 0)
        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.totalSize == 30)
    }

    @Test func emptyPublicationResetsSummary() {
        let viewModel = XcodeCleanerViewModel()
        viewModel.itemsByCategory = [.derivedData: [item("a", size: 100, category: .derivedData, selected: true)]]
        #expect(viewModel.selectedSize == 100)

        viewModel.itemsByCategory = [:]
        #expect(viewModel.totalSize == 0)
        #expect(viewModel.selectedSize == 0)
        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.categorySummary.isEmpty)
    }
}