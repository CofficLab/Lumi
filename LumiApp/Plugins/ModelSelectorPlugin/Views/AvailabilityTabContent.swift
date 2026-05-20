import SwiftUI

/// ModelSelector 内的可用性 Tab 内容。
struct AvailabilityTabContent: View {
    var body: some View {
        AvailabilityDetailView(mode: .tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
