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
        .background(DesignTokens.Material.glass)
        .cornerRadius(DesignTokens.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(DesignTokens.Color.basePalette.subtleBorder.opacity(0.12), lineWidth: 0.5)
        )
    }
}
