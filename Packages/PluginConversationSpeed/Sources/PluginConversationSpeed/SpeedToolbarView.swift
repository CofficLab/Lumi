import SwiftUI

/// 流式速度工具栏视图。
///
/// 视图只负责渲染 ViewModel；Provider 观察和状态更新由插件的 Observers 负责。
struct SpeedToolbarView: View {
    @ObservedObject var viewModel: ConversationSpeedViewModel

    @State private var popoverShown = false

    var body: some View {
        Button {
            popoverShown.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 10, weight: .medium))
                Text(speedLabel)
                    .font(.system(size: 10, weight: .medium))
                    .contentTransition(.numericText())
            }
            .foregroundColor(viewModel.cachedTPS == nil ? .secondary : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                viewModel.cachedTPS == nil ? Color.secondary.opacity(0.12) : Color.orange.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Streaming output speed", bundle: .module))
        .popover(isPresented: $popoverShown, arrowEdge: .bottom) {
            SpeedPopover(
                tps: viewModel.cachedTPS,
                unavailabilityReason: viewModel.unavailabilityReason,
                modelName: viewModel.modelName,
                outputTokens: viewModel.outputTokens,
                streamingDurationMs: viewModel.streamingDurationMs,
                timeToFirstTokenMs: viewModel.timeToFirstTokenMs,
                providerID: viewModel.providerID,
                speedHistory: viewModel.speedHistory
            )
            .frame(width: 360)
        }
        .onChange(of: viewModel.selectedConversationID) { _, newValue in
            if newValue == nil {
                popoverShown = false
            }
        }
    }

    private var speedLabel: String {
        guard let cachedTPS = viewModel.cachedTPS else {
            return "—"
        }
        return String(format: "%.1f tok/s", cachedTPS)
    }
}
