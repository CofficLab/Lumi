import SwiftUI
import MagicKit

struct NetworkHistoryDetailView: View {
    @ObservedObject private var historyService = NetworkHistoryService.shared
    @State private var selectedRange: TimeRange = .hour1
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with Picker
            HStack {
                Text("历史趋势")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases) { range in
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
            NetworkHistoryGraphView(
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

#Preview {
    NetworkHistoryDetailView()
        .frame(width: 320, height: 200)
}
