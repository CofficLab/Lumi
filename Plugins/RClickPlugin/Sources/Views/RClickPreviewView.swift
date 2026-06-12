import SwiftUI
import LumiUI

public struct RClickPreviewView: View {
    public let config: RClickConfig

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(config.items) { item in
                if item.isEnabled {
                    PreviewMenuRow(item: item)
                }
            }
        }
        .padding(6)
        .frame(width: 220)
        .appSurface(
            style: .glass,
            cornerRadius: 8,
            borderColor: Color.white.opacity(0.12),
            lineWidth: 0.5
        )
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
