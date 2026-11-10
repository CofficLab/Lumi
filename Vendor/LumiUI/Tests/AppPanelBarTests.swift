import SwiftUI
import Testing
@testable import LumiUI

struct AppPanelBarTests {
    @Test
    @MainActor
    func barMatchesChatToolbarChromeSpec() {
        let bar = AppPanelBar { EmptyView() }

        #expect(bar.height == AppPanelChromeMetrics.breadcrumbBarHeight)
        #expect(bar.contentHeight == AppPanelChromeMetrics.breadcrumbContentHeight)
        #expect(bar.padding.top == AppPanelChromeMetrics.breadcrumbVerticalPadding)
        #expect(bar.padding.bottom == AppPanelChromeMetrics.breadcrumbVerticalPadding)
        #expect(bar.padding.leading == AppPanelChromeMetrics.breadcrumbHorizontalPadding)
        #expect(bar.padding.trailing == AppPanelChromeMetrics.breadcrumbHorizontalPadding)
    }

    @Test
    @MainActor
    func barHeightStaysConsistentWithContentRow() {
        let bar = AppPanelBar { EmptyView() }

        #expect(bar.height == bar.contentHeight + bar.padding.top + bar.padding.bottom)
        #expect(AppPanelChromeMetrics.breadcrumbItemSpacing == 8)
    }
}
