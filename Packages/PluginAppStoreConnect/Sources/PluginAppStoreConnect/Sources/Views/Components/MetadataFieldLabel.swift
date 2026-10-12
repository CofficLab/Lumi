import LumiUI
import SwiftUI

struct MetadataFieldLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            AppSectionLabel(title)
        }
    }
}
