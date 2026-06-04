#if canImport(XCTest)
import Combine
import LumiCoreKit
import XCTest
@testable import Lumi

final class WindowLayoutVMTests: XCTestCase {
    @MainActor
    func testRestorePersistedIgnoresUnchangedValues() {
        let vm = WindowLayoutVM()
        var emissions = 0
        let cancellable = vm.objectWillChange.sink { emissions += 1 }

        vm.restorePersisted(activeViewContainerIcon: "macbook.and.iphone")
        vm.restorePersisted(tabId: "PluginGit")
        vm.restorePersisted(detailId: "PluginGit.CommitHistory")
        vm.restorePersisted(ratios: ["Split.Panel": 0.4])
        vm.restorePersisted(bottomPanelVisible: false)
        vm.restorePersisted(contentPanelVisible: false)
        vm.restorePersisted(editorVisible: false)
        vm.restorePersisted(railVisible: false)
        vm.restorePersisted(rightSidebarVisible: false)

        XCTAssertEqual(emissions, 9)

        vm.restorePersisted(activeViewContainerIcon: "macbook.and.iphone")
        vm.restorePersisted(tabId: "PluginGit")
        vm.restorePersisted(detailId: "PluginGit.CommitHistory")
        vm.restorePersisted(ratios: ["Split.Panel": 0.4])
        vm.restorePersisted(bottomPanelVisible: false)
        vm.restorePersisted(contentPanelVisible: false)
        vm.restorePersisted(editorVisible: false)
        vm.restorePersisted(railVisible: false)
        vm.restorePersisted(rightSidebarVisible: false)

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
