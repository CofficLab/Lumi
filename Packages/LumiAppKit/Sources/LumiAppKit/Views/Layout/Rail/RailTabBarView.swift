import LumiCoreKit
import LumiUI
import SwiftUI

// MARK: - Rail Tab Bar View

struct RailTabBarView: View {
    @LumiTheme private var theme

    let tabs: [LumiPanelRailTabItem]
    @Binding var selectedTabID: String

    var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            AppTabBar(
                tabs: tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
                selectedTab: Binding(
                    get: { selectedTabID },
                    set: { newValue in
                        selectedTabID = newValue
                    }
                ),
                showText: false
            )
        }
        .borderBottom()
        .shadowMd()
    }
}
