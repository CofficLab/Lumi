import LumiUI
import SwiftUI

struct CoverArtSizeStrip: View {
    let sizes: [CoverArtPreviewSize]
    let selectedDisplayType: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sizes) { size in
                    Button {
                        onSelect(size.displayType)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(size.label)
                                .font(.caption.weight(selectedDisplayType == size.displayType ? .semibold : .regular))
                            Text("\(size.width)×\(size.height)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selectedDisplayType == size.displayType
                                ? Color.accentColor.opacity(0.16)
                                : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
