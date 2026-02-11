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
        .background(.regularMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}
