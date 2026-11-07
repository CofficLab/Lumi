import AppKit
import LumiUI
import SwiftUI
import KernelCore

/// 主菜单栏弹窗网络区块内联展示的高占用网络进程。
///
/// 行样式与 CPU 区块的 `TopProcessesView` 对齐：16pt 图标、11pt 名称、
/// 单列速率数值和迷你进度条。数值为当前采样周期内的下载 + 上传速率，
/// 不是累计字节；进度条以榜首进程速率为满格。
public struct TopNetworkProcessesView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: NetworkManagerViewModel

    public init(viewModel: NetworkManagerViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        let processes = viewModel.topNetworkProcesses
        let maxSpeed = processes.map(\.totalSpeed).max() ?? 0

        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(pluginLocalization.string("Top Processes"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if processes.isEmpty {
                Text(pluginLocalization.string(viewModel.hasProcessSnapshot ? "No active processes" : "Collecting..."))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(processes) { process in
                        processRow(process, maxSpeed: maxSpeed)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .background(
            // 菜单栏主弹窗的 NSPopover 会被复用，onAppear/onDisappear 不能可靠
            // 反映弹窗开关；改为监听视图所在窗口的可见性来启停 nettop。
            WindowVisibilityObserver { isVisible in
                if isVisible {
                    viewModel.acquireProcessMonitor()
                } else {
                    viewModel.releaseProcessMonitor()
                }
            }
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        )
    }

    // MARK: - 私有方法

    private func processRow(_ process: NetworkProcess, maxSpeed: Double) -> some View {
        HStack(spacing: 8) {
            // 进程图标
            iconForProcess(process)
                .resizable()
                .frame(width: 16, height: 16)

            // 进程名 + 同名份数 + 本应用标注
            HStack(spacing: 4) {
                Text(process.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if process.instanceCount > 1 {
                    Text("×\(process.instanceCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }

                if process.isCurrentApp {
                    Text(pluginLocalization.string("This app"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 当前速率：按速率展示，单位随量级切换；已过滤零速率进程。
            Text(SpeedFormatter.formatForStatusBar(process.totalSpeed))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .lineLimit(1)
                .frame(width: 64, alignment: .trailing)

            // 进度条：以榜首进程速率为满格。
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))

                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: geometry.size.width * barFraction(for: process, maxSpeed: maxSpeed))
                }
            }
            .frame(width: 40, height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func iconForProcess(_ process: NetworkProcess) -> Image {
        if let icon = process.icon {
            return Image(nsImage: icon)
        }
        return Image(systemName: "gearshape")
    }

    private func barFraction(for process: NetworkProcess, maxSpeed: Double) -> CGFloat {
        guard maxSpeed > 0 else { return 0 }
        return CGFloat(min(max(process.totalSpeed / maxSpeed, 0), 1))
    }
}

// MARK: - 窗口可见性

/// 观察 SwiftUI 视图所在 NSWindow 的可见性。
///
/// 菜单栏主弹窗复用一个 `NSPopover` 与其 `NSHostingController`，视图不会随
/// 弹窗关闭而销毁，因此 `onAppear/onDisappear` 无法用来启停 nettop。
private struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> WindowVisibilityTrackingView {
        let view = WindowVisibilityTrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: WindowVisibilityTrackingView, context: Context) {
        nsView.onChange = onChange
    }
}

private final class WindowVisibilityTrackingView: NSView {
    var onChange: ((Bool) -> Void)?

    private weak var trackedWindow: NSWindow?
    private var timer: Timer?
    private var lastValue: Bool?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else {
            timer?.invalidate()
            timer = nil
            trackedWindow = nil
            evaluateVisibility()
            return
        }

        trackedWindow = window
        lastValue = nil
        startTimer()
        evaluateVisibility()
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(
            timeInterval: 0.75,
            target: self,
            selector: #selector(handleTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func handleTick() {
        evaluateVisibility()
    }

    private func evaluateVisibility() {
        let isVisible = trackedWindow?.isVisible ?? false
        guard lastValue != isVisible else { return }
        lastValue = isVisible
        onChange?(isVisible)
    }
}

// MARK: - 预览

#Preview("Top Network Processes") {
    TopNetworkProcessesView(viewModel: NetworkManagerViewModel())
        .frame(width: 280)
        .padding()
}
