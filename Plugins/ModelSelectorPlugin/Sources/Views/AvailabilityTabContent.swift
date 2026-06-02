import SwiftUI

/// ModelSelector 内的可用性 Tab 内容。
public struct AvailabilityTabContent: View {
    public var body: some View {
        AvailabilityDetailView(mode: .tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
