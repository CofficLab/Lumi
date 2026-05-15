import SwiftUI

struct ActivityHeatStripView: View {
    let scores: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "24-hour activity", table: "IdleTime"))
                .font(.caption)
                .foregroundColor(secondaryTextColor)

            HStack(spacing: 2) {
                ForEach(0..<RestWindowInferencer.bucketsPerDay, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: normalizedScore(at: index)))
                        .frame(width: 7, height: 24)
                }
            }

            HStack {
                Text("00")
                Spacer()
                Text("06")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("24")
            }
            .font(.caption2)
            .foregroundColor(secondaryTextColor)
        }
    }

    private func normalizedScore(at index: Int) -> Double {
        guard scores.indices.contains(index),
              let maxScore = scores.max(),
              maxScore > 0 else {
            return 0
        }
        return scores[index] / maxScore
    }

    private func color(for normalized: Double) -> Color {
        if normalized <= 0 {
            return secondaryTextColor.opacity(0.12)
        }
        return Color.accentColor.opacity(0.18 + normalized * 0.72)
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }
}
