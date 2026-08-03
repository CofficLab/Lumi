import SwiftUI

// MARK: - TipView

/// Tip card shown at the bottom of onboarding pages.
struct TipView: View {
    let tip: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            Text(tip)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.yellow.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Convenience View Builder

@ViewBuilder
func tipCard(_ tip: String) -> some View {
    TipView(tip: tip)
}

#Preview("Tip View") {
    TipView(tip: "You can change plugin settings at any time.")
        .padding()
        .frame(width: 520)
}
