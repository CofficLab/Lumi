#if canImport(XCTest)
import Combine
import LumiCoreKit
import XCTest
@testable import Lumi

final class WindowLayoutVMTests: XCTestCase {
    @MainActor
    func testRestoreFromPluginIgnoresUnchangedValues() {
        let vm = WindowLayoutVM()
        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }

        vm.restoreFromPlugin(activeViewContainerIcon: "macbook.and.iphone")
        vm.restoreFromPlugin(tabId: "PluginGit")
        vm.restoreFromPlugin(detailId: "PluginGit.CommitHistory")
        vm.restoreFromPlugin(ratios: ["Split.Panel": 0.4])
        vm.restoreFromPlugin(bottomPanelVisible: false)
        vm.restoreFromPlugin(contentPanelVisible: false)
        vm.restoreFromPlugin(editorVisible: false)
        vm.restoreFromPlugin(railVisible: false)
        vm.restoreFromPlugin(rightSidebarVisible: false)

        XCTAssertEqual(emissions, 9)

        vm.restoreFromPlugin(activeViewContainerIcon: "macbook.and.iphone")
        vm.restoreFromPlugin(tabId: "PluginGit")
        vm.restoreFromPlugin(detailId: "PluginGit.CommitHistory")
        vm.restoreFromPlugin(ratios: ["Split.Panel": 0.4])
        vm.restoreFromPlugin(bottomPanelVisible: false)
        vm.restoreFromPlugin(contentPanelVisible: false)
        vm.restoreFromPlugin(editorVisible: false)
        vm.restoreFromPlugin(railVisible: false)
        vm.restoreFromPlugin(rightSidebarVisible: false)

        XCTAssertEqual(emissions, 9)
        cancellable.cancel()
    }

    @MainActor
    func testRestoreSelectedEmptyListsDoNotRepublishEmptySelections() {
        let vm = WindowLayoutVM()
        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }

        vm.restoreSelectedTab(from: [])
        vm.restoreSelectedDetail(from: [])
        vm.clearSelectedTab()
        vm.clearSelectedDetail()

        XCTAssertEqual(emissions, 0)
        cancellable.cancel()
    }

    @MainActor
    func testPluginLayoutContextUpdateOnlyPublishesChangedFields() {
        let vm = LumiCoreKit.WindowLayoutVM()
        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }

        vm.update(
            bottomPanelVisible: false,
            contentPanelVisible: true,
            editorVisible: true,
            railVisible: true,
            rightSidebarVisible: true,
            activeViewContainerIcon: nil,
            selectedAgentSidebarTabId: "",
            selectedAgentDetailId: "",
            layoutRatios: [:]
        )

        XCTAssertEqual(emissions, 1)

        vm.update(
            bottomPanelVisible: false,
            contentPanelVisible: true,
            editorVisible: true,
            railVisible: true,
            rightSidebarVisible: true,
            activeViewContainerIcon: nil,
            selectedAgentSidebarTabId: "",
            selectedAgentDetailId: "",
            layoutRatios: [:]
        )

        XCTAssertEqual(emissions, 1)
        cancellable.cancel()
    }
}
#endif
