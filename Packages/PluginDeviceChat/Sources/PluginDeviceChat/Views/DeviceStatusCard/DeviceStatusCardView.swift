import LumiUI
import PluginDevice
import ProviderMessage
import SwiftUI

/// 设备状态卡片视图。
///
/// 按查询范围（`DeviceStatusScope`）渲染对应区块：
/// - `overview`：CPU / 内存 / GPU / 电池 / 磁盘 一屏总览；
/// - `cpu`：总占用 + 每核分布 + 负载均值 + user/system/idle 拆分；
/// - `memory`：已用 / 总量 / 内存压力；
/// - `storage`：各卷容量条；
/// - `thermal`：传感器读数与峰值；
/// - `processes`：进程排行。
///
/// 载荷缺失时（历史数据或载荷损坏）回退到纯文本摘要，避免渲染空白。
struct DeviceStatusCardView: View {
    @LumiTheme private var theme

    let payload: DeviceStatusPayload

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                content
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.info)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch payload.scope {
        case .overview:
            DeviceStatusOverviewSection(payload: payload)
        case .cpu:
            DeviceStatusCPUSection(cpu: payload.cpu)
        case .memory:
            DeviceStatusMemorySection(memory: payload.memory)
        case .storage:
            DeviceStatusStorageSection(volumes: payload.volumes)
        case .thermal:
            DeviceStatusThermalSection(thermal: payload.thermal)
        case .processes:
            DeviceStatusProcessesSection(processes: payload.processes)
        }
    }

    // MARK: - Display

    private var titleText: String {
        switch payload.scope {
        case .overview:
            return pluginLocalization.string("Device Status")
        case .cpu:
            return pluginLocalization.string("CPU")
        case .memory:
            return pluginLocalization.string("Memory")
        case .storage:
            return pluginLocalization.string("Storage")
        case .thermal:
            return pluginLocalization.string("Temperature")
        case .processes:
            return pluginLocalization.string("Top Processes")
        }
    }

    private var subtitleText: String {
        let name = payload.device.name.isEmpty
            ? pluginLocalization.string("This Mac")
            : payload.device.name
        return "\(name) · \(payload.device.osVersion)"
    }

    private var iconName: String {
        switch payload.scope {
        case .overview:
            return "gauge.with.dots.needle.50percent"
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .storage:
            return "internaldrive"
        case .thermal:
            return "thermometer.medium"
        case .processes:
            return "list.bullet.rectangle"
        }
    }
}

/// 载荷缺失时的降级视图：只显示消息正文。
struct DeviceStatusCardFallbackView: View {
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
