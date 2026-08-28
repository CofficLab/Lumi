import LumiUI
import SwiftUI

/// A tabbed payload view for JSON response bodies. Shows a segmented picker
/// with "Raw" and "Parsed" tabs, allowing the user to switch between the
/// original response text and a pretty-printed JSON representation.
struct HTTPExchangeJSONBodyTabs: View {
    @LumiTheme private var theme

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

    var body: some View {
        VStack(spacing: 8) {
            // Tab picker
            HStack {
                Picker("", selection: $selectedTab) {
                    ForEach(DisplayTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()
            }

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
