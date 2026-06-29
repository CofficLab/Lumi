import SwiftUI
import LumiUI
import LumiCoreKit

struct CPUHistoryDetailView: View {
    @ObservedObject private var historyService = CPUHistoryService.shared
    @State private var selectedRange: CPUTimeRange = .hour1

    var body: some View {
        VStack(spacing: 12) {
            // Header with Picker
            HStack {
                Text(LumiPluginLocalization.string("CPU Load Trend", bundle: .module))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "98989E"))

                Spacer()

                Picker(LumiPluginLocalization.string("Time Range", bundle: .module), selection: $selectedRange) {
                    ForEach(CPUTimeRange.allCases) { range in
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

            // Graph
            AppCard(cornerRadius: 0, padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0), showShadow: false) {
                CPUHistoryGraphView(
                    dataPoints: historyService.getData(for: selectedRange),
                    timeRange: selectedRange
                )
            }
            .frame(height: 180)
        }
    }
}

