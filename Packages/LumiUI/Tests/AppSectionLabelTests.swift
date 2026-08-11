import SwiftUI
import Testing
@testable import LumiUI

struct AppSectionLabelTests {
    @Test
    @MainActor
    func storesDefaultColorWhenOmitted() {
        let label = AppSectionLabel("App Versions")
        #expect(label.color == nil)
    }

    @Test
    @MainActor
    func storesColorOverride() {
        let label = AppSectionLabel("Platform", color: .blue)
        #expect(label.color == .blue)
    }
}
