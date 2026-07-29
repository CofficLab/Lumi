import SwiftUI
import LumiUI

/// GitHub-style activity heatmap showing daily message counts as colored cells.
public struct ActivityHeatmapView: View {
    public let data: [ActivityDay]
    public let isLoading: Bool

    @State private var isBreathing = false

    // GitHub-style heatmap colors (5 levels)
    private let colors: [Color] = [
        Color(hex: "1e2530"),  // Level 0: no activity
        Color(hex: "2d4a6e"),  // Level 1
        Color(hex: "3d6a9e"),  // Level 2
        Color(hex: "4d8ace"),  // Level 3
        Color(hex: "6db0f0"),  // Level 4
    ]

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3

    public init(data: [ActivityDay], isLoading: Bool = false) {
        self.data = data
        self.isLoading = isLoading
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and legend
            HStack {
                Text(LumiPluginLocalization.string("Activity Heatmap", bundle: .module))
                    .font(.appBody)
                    .bold()
                Spacer()
                HStack(spacing: 6) {
                    Text(LumiPluginLocalization.string("Less", bundle: .module))
                        .font(.appCaption)
                    ForEach(0..<colors.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors[i])
                            .frame(width: 14, height: 14)
                    }
                    Text(LumiPluginLocalization.string("More", bundle: .module))
                        .font(.appCaption)
                }
            }

            // Heatmap grid
            heatmapGrid
        }
        .onAppear {
            updateBreathingState()
        }
        .onChange(of: isLoading) { _, _ in
            updateBreathingState()
        }
    }

    private var heatmapGrid: some View {
        let weeks = chunkIntoWeeks(data)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(Array(week.enumerated()), id: \.element.id) { dayIndex, day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cellColor(for: day, index: weekIndex * 7 + dayIndex))
                                .frame(width: cellSize, height: cellSize)
                                .animation(
                                    isLoading
                                        ? .easeInOut(duration: 1.6)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double((weekIndex * 7 + dayIndex) % 9) * 0.08)
                                        : .easeOut(duration: 0.35),
                                    value: isBreathing
                                )
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func cellColor(for day: ActivityDay, index: Int) -> Color {
        guard isLoading else {
            return colors[min(day.level, colors.count - 1)]
        }

        let baseOpacity = 0.28 + Double((index * 17) % 5) * 0.035
        let breathingOpacity = isBreathing ? baseOpacity + 0.18 : baseOpacity
        return colors[0].opacity(breathingOpacity)
    }

    private func updateBreathingState() {
        guard isLoading else {
            isBreathing = false
            return
        }

        isBreathing = false
        withAnimation {
            isBreathing = true
        }
    }

    private func chunkIntoWeeks(_ days: [ActivityDay]) -> [[ActivityDay]] {
        stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }
}

#Preview {
    ActivityHeatmapView(data: [])
        .frame(width: 480, height: 200)
        .padding()
}
