import SwiftUI
import MagicKit

struct CPUHistoryDetailView: View {
    @ObservedObject private var historyService = CPUHistoryService.shared
    @State private var selectedRange: CPUTimeRange = .hour1
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with Picker
            HStack {
                Text("CPU Load Trend")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(CPUTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
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
            CPUHistoryGraphView(
                dataPoints: historyService.getData(for: selectedRange),
                timeRange: selectedRange
            )
            .frame(height: 140)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Preview

#Preview("App") {
    CPUStatusBarPopupView()
        .inRootView()
        .frame(width: 300)
        .frame(height: 300)
}
