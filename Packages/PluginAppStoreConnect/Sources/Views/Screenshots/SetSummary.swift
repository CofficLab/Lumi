import SwiftUI

struct ScreenshotSetSummary: View {
    let sets: [ScreenshotSet]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if sets.isEmpty {
                    Text(AppStoreConnectLocalization.string("No screenshot sets loaded"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sets) { set in
                        Text(set.screenshotDisplayType)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
