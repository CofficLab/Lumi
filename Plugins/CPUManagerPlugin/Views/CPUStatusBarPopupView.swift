import SwiftUI
import MagicKit

struct CPUStatusBarPopupView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CPUManagerViewModel()
    @State private var isHovering = false
    @State private var hideWorkItem: DispatchWorkItem?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // 标题栏
            headerView

            // 实时负载显示
            liveLoadView
                .background(Color.clear) // Ensure hit testing works
                .onHover { hovering in
                    updateHoverState(hovering: hovering)
                }
                .popover(isPresented: $isHovering, arrowEdge: .leading) {
                    CPUHistoryDetailView()
                        .onHover { hovering in
                            updateHoverState(hovering: hovering)
                        }
                }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 14))
                .foregroundColor(.blue)

            Text("CPU 监控")
                .font(.system(size: 13, weight: .semibold))

            Spacer()
        }.padding(.horizontal)
    }

    // MARK: - Live Load View

    private var liveLoadView: some View {
        HStack(spacing: 16) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.cpuUsage / 100.0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: viewModel.cpuUsage)
                
                Text("\(Int(viewModel.cpuUsage))%")
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("当前使用率")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f%%", viewModel.cpuUsage))
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
        }
        .padding(10)
        .background(.background.opacity(0.5))
    }
    
    // MARK: - Hover Logic
    
    private func updateHoverState(hovering: Bool) {
        // Cancel any pending hide action
        hideWorkItem?.cancel()
        hideWorkItem = nil
        
        if hovering {
            // If mouse enters either view, keep showing
            isHovering = true
        } else {
            // If mouse leaves, wait a bit before hiding
            // This gives time to move between the source view and the popover
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
    CPUStatusBarPopupView()
        .inRootView()
        .withDebugBar()
}
