import SwiftUI
import LumiUI

struct ActivityHeatmapView: View {
    let data: [ActivityDay]

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and legend
            HStack {
                Text("活跃热力图")
                    .font(.appBody)
                    .bold()
                Spacer()
                HStack(spacing: 6) {
                    Text("较少")
                        .font(.appCaption)
                    ForEach(0..<colors.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors[i])
                            .frame(width: 14, height: 14)
                    }
                    Text("较多")
                        .font(.appCaption)
                }
            }

            // Heatmap grid
            heatmapGrid
        }
    }

    private var heatmapGrid: some View {
        // Organize by column (week): 7 days per week
        let weeks = chunkIntoWeeks(data)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors[min(day.level, colors.count - 1)])
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
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
}
