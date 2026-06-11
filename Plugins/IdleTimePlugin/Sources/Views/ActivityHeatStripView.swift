import SwiftUI
import LumiUI

public struct ActivityHeatStripView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let scores: [Double]

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "24-hour activity", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            HStack(spacing: 2) {
                ForEach(0..<RestWindowInferencer.bucketsPerDay, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: normalizedScore(at: index)))
                        .frame(width: 7, height: 24)
                }
            }

            HStack {
                Text("00", bundle: .module)
                Spacer()
                Text("06", bundle: .module)
                Spacer()
                Text("12", bundle: .module)
                Spacer()
                Text("18", bundle: .module)
                Spacer()
                Text("24", bundle: .module)
            }
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)
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
            return theme.textSecondary.opacity(0.12)
        }
        return theme.primary.opacity(0.18 + normalized * 0.72)
    }
}
