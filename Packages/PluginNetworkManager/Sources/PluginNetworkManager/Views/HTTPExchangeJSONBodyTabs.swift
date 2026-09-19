import LumiUI
import SwiftUI

/// A tabbed payload view for JSON response bodies. Shows a segmented picker
/// with "Raw" and "Parsed" tabs, allowing the user to switch between the
/// original response text and a pretty-printed JSON representation.
struct HTTPExchangeJSONBodyTabs: View {
    let data: Data?
    let fallback: String

    private enum DisplayTab: String, CaseIterable {
        case raw
        case parsed

        var title: String {
            switch self {
            case .raw:
                LumiPluginLocalization.string("Raw", bundle: .module)
            case .parsed:
                LumiPluginLocalization.string("Parsed", bundle: .module)
            }
        }
    }

    @State private var selectedTab: DisplayTab = .parsed

    private var selectedTabIndex: Binding<Int> {
        Binding(
            get: { DisplayTab.allCases.firstIndex(of: selectedTab) ?? 0 },
            set: { selectedTab = DisplayTab.allCases[$0] }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            // Tab picker
            AppSegmentedControl(DisplayTab.allCases.map(\.title), selection: selectedTabIndex, maxWidth: 200)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Content
            switch selectedTab {
            case .raw:
                HTTPExchangePayloadView(data: data, fallback: fallback, rawMode: true)
            case .parsed:
                HTTPExchangePayloadView(data: data, fallback: fallback, rawMode: false)
            }
        }
    }
}
