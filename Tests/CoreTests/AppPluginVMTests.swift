#if canImport(XCTest)
import SwiftUI
import XCTest
@testable import Lumi

final class AppPluginVMTests: XCTestCase {
    @MainActor
    func testDisabledPluginsDoNotContributeViewContainers() {
        let vm = AppPluginVM(autoDiscover: false)
        vm.replacePluginsForTesting([
            FirstDuplicateIconPlugin.shared,
            SecondDuplicateIconPlugin.shared
        ])

        let items = vm.getViewContainerItems()

        XCTAssertTrue(items.isEmpty)
    }
}

private actor FirstDuplicateIconPlugin: SuperPlugin {
    static let shared = FirstDuplicateIconPlugin()
    static let id = "FirstDuplicateIcon"
    static let displayName = "First Duplicate Icon"
    static let category: PluginCategory = .general
    static let order = 10

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(
            id: "first-duplicate-icon",
            title: "First",
            icon: "square.grid.2x2",
            makeView: { AnyView(EmptyView()) }
        )
    }
}

private actor SecondDuplicateIconPlugin: SuperPlugin {
    static let shared = SecondDuplicateIconPlugin()
    static let id = "SecondDuplicateIcon"
    static let displayName = "Second Duplicate Icon"
    static let category: PluginCategory = .general
    static let order = 20

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(
            id: "second-duplicate-icon",
            title: "Second",
            icon: "square.grid.2x2",
            makeView: { AnyView(EmptyView()) }
        )
    }
}
#endif
