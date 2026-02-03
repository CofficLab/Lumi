import SwiftUI
import MagicKit

struct MemoryStatusBarPopupView: View {
    @StateObject private var viewModel = MemoryManagerViewModel()
    @State private var isHovering = false
    @State private var hideWorkItem: DispatchWorkItem?
    
    var body: some View {
        VStack(spacing: 12) {
            headerView
            
            liveStatsView
                .background(Color.clear)
                .onHover { hovering in
                    updateHoverState(hovering: hovering)
                }
                .popover(isPresented: $isHovering, arrowEdge: .leading) {
                    MemoryHistoryDetailView()
                        .onHover { hovering in
                            updateHoverState(hovering: hovering)
                        }
                }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "memorychip")
                .font(.system(size: 14))
                .foregroundColor(.purple)
            
            Text("内存监控")
                .font(.system(size: 13, weight: .semibold))
            
            Spacer()
        }.padding(.horizontal)
    }
    
    private var liveStatsView: some View {
        HStack(spacing: 16) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.memoryUsagePercentage / 100.0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .blue]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: viewModel.memoryUsagePercentage)
                
                Text("\(Int(viewModel.memoryUsagePercentage))%")
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("已用: \(viewModel.usedMemory)")
                    .font(.system(size: 14, weight: .medium))
                
                Text("总量: \(viewModel.totalMemory)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(.background.opacity(0.5))
    }
    
    private func updateHoverState(hovering: Bool) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        
        if hovering {
            isHovering = true
        } else {
            let workItem = DispatchWorkItem {
                isHovering = false
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
}

// MARK: - Preview

#Preview("App") {
    MemoryStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
