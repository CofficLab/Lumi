import SwiftUI
import Testing
@testable import LumiUI

struct AppSidebarRowTests {
    @Test
    @MainActor
    func storesTitleAndSystemImage() {
        let row = AppSidebarRow(
            title: "Account",
            systemImage: "person.crop.circle",
            isSelected: true,
            action: {}
        ) as AppSidebarRow<EmptyView>
        #expect(row.title == "Account")
        #expect(row.systemImage == "person.crop.circle")
        #expect(row.isSelected == true)
    }

    @Test
    @MainActor
    func reflectsSelectionState() {
        let selected = AppSidebarRow(title: "A", isSelected: true, action: {})
            as AppSidebarRow<EmptyView>
        let normal = AppSidebarRow(title: "B", isSelected: false, action: {})
            as AppSidebarRow<EmptyView>
        #expect(selected.isSelected == true)
        #expect(normal.isSelected == false)
    }

    @Test
    @MainActor
    func omitsLeadingImageWhenNil() {
        let row = AppSidebarRow(title: "No Icon", isSelected: false, action: {})
            as AppSidebarRow<EmptyView>
        #expect(row.systemImage == nil)
        #expect(row.leadingColor == nil)
    }
}
