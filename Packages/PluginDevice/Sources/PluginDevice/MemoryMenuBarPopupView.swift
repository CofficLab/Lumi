import LumiUI
import SwiftUI

public struct MemoryMenuBarPopupView: View {
    @StateObject private var viewModel = MemoryManagerViewModel()

    public var body: some View {
        HoverableContainerView(detailView: MemoryHistoryDetailView()) {
            liveStatsView
        }
    }

    private var liveStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LumiPluginLocalization.string("Memory", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(viewModel.usedMemory) / \(viewModel.totalMemory)")
                    .font(.system(size: 12, weight: .medium))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.accentColor, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.memoryUsagePercentage / 100.0))
                }
            }
            .frame(height: 6)
        }
        .padding(10)
    }
}
