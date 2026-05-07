import SwiftUI

struct RClickPreviewView: View {
    let config: RClickConfig

    var body: some View {
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
            cornerRadius: AppUI.Radius.sm,
            borderColor: AppUI.Color.basePalette.subtleBorder.opacity(0.12),
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
