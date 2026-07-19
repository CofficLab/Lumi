import SwiftUI
import LumiUI
import LumiKernel

public struct ActivityHeatStripView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let scores: [Double]

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LumiPluginLocalization.string("24-hour activity", bundle: .module))
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
                Text(verbatim: LumiPluginLocalization.string("00", bundle: .module))
                Spacer()
                Text(verbatim: LumiPluginLocalization.string("06", bundle: .module))
                Spacer()
                Text(verbatim: LumiPluginLocalization.string("12", bundle: .module))
                Spacer()
                Text(verbatim: LumiPluginLocalization.string("18", bundle: .module))
                Spacer()
                Text(verbatim: LumiPluginLocalization.string("24", bundle: .module))
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
