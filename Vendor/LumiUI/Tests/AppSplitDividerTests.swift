import SwiftUI
import Testing
@testable import LumiUI

struct AppSplitDividerTests {
    @Test
    @MainActor
    func restingShadowIsVisibleByDefault() {
        // Default call sites keep the historical subtle inset shadow.
        #expect(AppSplitDividerShadow.opacity(isHovered: false, restingShadow: true) == 0.04)
    }

    @Test
    @MainActor
    func restingShadowCanBeHidden() {
        // Opting out removes the shadow while at rest...
        #expect(AppSplitDividerShadow.opacity(isHovered: false, restingShadow: false) == 0)
    }

    @Test
    @MainActor
    func hoverAlwaysRevealsTheShadow() {
        // ...but hovering still reveals it, so the divider stays discoverable.
        #expect(AppSplitDividerShadow.opacity(isHovered: true, restingShadow: true) == 0.1)
        #expect(AppSplitDividerShadow.opacity(isHovered: true, restingShadow: false) == 0.1)
    }
}
