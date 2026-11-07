import LumiUI
import ProviderMessage
import SwiftUI

/// 磁盘测速卡片视图。
///
/// 测速进行中时显示旋转指示器与「正在测试硬盘速度…」；
/// 完成后显示读 / 写两项速度；失败时显示失败原因。
///
/// 载荷缺失时（历史数据或载荷损坏）回退到纯文本摘要，避免渲染空白。
struct DiskSpeedCardView: View {
    @LumiTheme private var theme

    let payload: DiskSpeedPayload

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                if payload.phase == .finished {
                    Divider()
                        .overlay(theme.divider.opacity(0.6))

                    metrics
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            if payload.phase == .running {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Metrics

    /// 完成后的读 / 写速度两行。
    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricRow(
                label: pluginLocalization.string("Read"),
                value: payload.displayReadSpeed ?? pluginLocalization.string("Unavailable")
            )
            metricRow(
                label: pluginLocalization.string("Write"),
                value: payload.displayWriteSpeed ?? pluginLocalization.string("Unavailable")
            )
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Display

    private var titleText: String {
        switch payload.phase {
        case .running:
            return pluginLocalization.string("Testing disk speed…")
        case .finished:
            return pluginLocalization.string("Disk speed test completed")
        case .failed:
            return pluginLocalization.string("Disk speed test failed")
        }
    }

    private var subtitleText: String? {
        switch payload.phase {
        case .running:
            return pluginLocalization.string("Writing and reading a temporary file to measure throughput.")
        case .finished:
            let size = DiskSpeedPayload.formattedBytes(payload.readBytes)
            return pluginLocalization.string("Sample size") + ": " + size
        case .failed:
            guard let reason = payload.failureReason, !reason.isEmpty else { return nil }
            return reason
        }
    }

    private var iconName: String {
        switch payload.phase {
        case .running:
            return "gauge.with.dots.needle.bottom.50percent"
        case .finished:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch payload.phase {
        case .running:
            return theme.primary
        case .finished:
            return theme.success
        case .failed:
            return theme.warning
        }
    }
}

/// 载荷缺失时的降级视图：只显示消息正文。
struct DiskSpeedCardFallbackView: View {
    @LumiTheme private var theme

    let message: Message

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            Text(message.content)
                .font(.callout)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
