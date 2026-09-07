import LumiUI
import SwiftUI

/// 卸载浮层的运行阶段。
enum UninstallOverlayPhase: Equatable {
    /// 卸载进行中。
    case running
    /// 卸载完成，`applicationMovedToTrash` 表示应用是否已移入废纸篓。
    case succeeded(applicationMovedToTrash: Bool)
    /// 卸载失败，`detail` 为可复制的失败明细。
    case failed(detail: String)
}

/// 独立浮层中的卸载进度 / 结果视图（「卸载中」「卸载完成」「卸载失败」三态）。
///
/// 卸载会清除 Lumi 自身数据，设置主窗口内容在卸载过程中可能失效，因此
/// 这三个阶段放在与主窗口解耦的独立无边框浮层中呈现。浮层内直接使用
/// LumiUI 组件渲染（主题经 `LumiUIThemeStore` 全局注入，无需额外环境值）。
struct UninstallOverlayView: View {
    @LumiTheme private var theme

    /// 卸载完成后的自动退出倒计时（秒）。
    static let exitCountdownSeconds = 3

    let phase: UninstallOverlayPhase
    let onExit: @MainActor () -> Void
    let onClose: @MainActor () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.divider.opacity(0.6), lineWidth: 1)
                )

            content
                .padding(26)
        }
        .frame(width: 420, height: 380)
        .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .running:
            RunningView()
        case let .succeeded(applicationMovedToTrash):
            SucceededView(
                applicationMovedToTrash: applicationMovedToTrash,
                onExit: onExit
            )
        case let .failed(detail):
            FailedView(detail: detail, onClose: onClose)
        }
    }
}

// MARK: - 卸载中

private struct RunningView: View {
    var body: some View {
        VStack(spacing: 18) {
            AppSheetIconHeader(systemImage: "trash.fill", title: nil as String?, tint: .red)

            VStack(spacing: 6) {
                Text("正在卸载 Lumi…")
                    .font(.appTitle)
                Text("正在清除插件数据、偏好设置、扩展数据和凭据。")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AppLoadingOverlay(message: "此操作无法撤销", size: .small)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 卸载完成

private struct SucceededView: View {
    let applicationMovedToTrash: Bool
    let onExit: @MainActor () -> Void

    @State private var countdown = UninstallOverlayView.exitCountdownSeconds

    var body: some View {
        VStack(spacing: 18) {
            AppSheetIconHeader(systemImage: "checkmark.circle.fill", title: nil as String?, tint: .green)

            VStack(spacing: 6) {
                Text("卸载完成")
                    .font(.appTitle)
                Text(applicationMovedToTrash
                     ? "Lumi 已从你的 Mac 移除，应用已移到废纸篓。"
                     : "Lumi 数据已清除，应用即将退出。")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 4) {
                Text("\(countdown)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Text("秒后自动退出")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            countdown = UninstallOverlayView.exitCountdownSeconds
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
            onExit()
        }
    }
}

// MARK: - 卸载失败

private struct FailedView: View {
    @LumiTheme private var theme

    let detail: String
    let onClose: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 14) {
            AppSheetIconHeader(systemImage: "exclamationmark.triangle.fill", title: nil as String?, tint: .orange)

            VStack(spacing: 6) {
                Text("卸载未完成")
                    .font(.appTitle)
                Text("部分数据未能清除，应用未移除。")
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 92)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.overlay.opacity(0.5))
            )

            AppButton("关闭", style: .secondary, size: .medium) {
                onClose()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
