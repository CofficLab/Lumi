import SwiftUI
import MagicKit

struct MemoryHistoryDetailView: View {
    @ObservedObject private var historyService = MemoryHistoryService.shared
    @State private var selectedRange: MemoryTimeRange = .hour1
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("内存使用趋势")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(MemoryTimeRange.allCases) { range in
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
            MemoryHistoryGraphView(
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
