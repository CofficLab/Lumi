import SwiftUI
import LumiUI

struct MemoryHistoryDetailView: View {
    @ObservedObject private var historyService = MemoryHistoryService.shared
    @State private var selectedRange: MemoryTimeRange = .hour1

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LumiPluginLocalization.string("Memory Usage Trend", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "98989E"))

                Spacer()

                Picker(LumiPluginLocalization.string("Time Range", bundle: .module), selection: $selectedRange) {
                    ForEach(MemoryTimeRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 160)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            AppCard(cornerRadius: 0, padding: EdgeInsets(), showShadow: false) {
                MemoryHistoryGraphView(
                    dataPoints: historyService.getData(for: selectedRange),
                    timeRange: selectedRange
                )
            }
            .frame(height: 180)
        }
    }
}

