import SwiftUI
import MagicKit

/// 状态栏弹窗视图
struct StatusBarPopupView: View {
    // MARK: - Properties

    /// 插件菜单项
    let pluginMenuItems: [NSMenuItem]

    /// 显示主窗口
    let onShowMainWindow: () -> Void

    /// 检查更新
    let onCheckForUpdates: () -> Void

    /// 退出应用
    let onQuit: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 第一部分：应用基本信息
            appInfoSection

            Divider()

            // 第二部分：菜单项
            menuItemsSection
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(spacing: 12) {
            // 应用图标和名称
            HStack(spacing: 12) {
                // 应用图标
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }

                // 应用信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lumi")
                        .font(.system(size: 16, weight: .semibold))

                    Text("系统工具箱")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("v\(appVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 运行状态信息
            HStack(spacing: 16) {
                SystemStatusItem(
                    icon: "cpu.fill",
                    label: "CPU",
                    value: getCPUUsage()
                )

                SystemStatusItem(
                    icon: "memorychip.fill",
                    label: "内存",
                    value: getMemoryUsage()
                )

                Spacer()
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Menu Items Section

    private var menuItemsSection: some View {
        VStack(spacing: 0) {
            // 打开 Lumi
            MenuItemRow(
                icon: "window.rectangle",
                title: "打开 Lumi",
                subtitle: "显示主窗口",
                action: onShowMainWindow
            )

            Divider()
                .padding(.horizontal, 8)

            // 检查更新
            MenuItemRow(
                icon: "arrow.down.circle",
                title: "检查更新",
                subtitle: "获取最新版本",
                action: onCheckForUpdates
            )

            if !pluginMenuItems.isEmpty {
                Divider()
                    .padding(.horizontal, 8)

                // 插件菜单项
                ForEach(pluginMenuItems.indices, id: \.self) { index in
                    let item = pluginMenuItems[index]

                    PluginMenuItemRow(menuItem: item)

                    if index < pluginMenuItems.count - 1 {
                        Divider()
                            .padding(.horizontal, 8)
                    }
                }
            }

            Divider()
                .padding(.horizontal, 8)

            // 退出应用
            MenuItemRow(
                icon: "power",
                title: "退出 Lumi",
                subtitle: "完全退出应用",
                color: .red,
                action: onQuit
            )
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func getCPUUsage() -> String {
        // 简单的 CPU 使用率获取
        var totalUsageOfCPU: Double = 0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                }
            }

            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        return String(format: "%.0f%%", totalUsageOfCPU)
    }

    private func getMemoryUsage() -> String {
        // 获取内存使用情况
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return "N/A"
        }

        let pageSize = vm_kernel_page_size
        let usedMemory = UInt64(stats.active_count) * UInt64(pageSize)
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        let usedGB = Double(usedMemory) / 1_073_741_824.0
        let totalGB = Double(totalMemory) / 1_073_741_824.0

        return String(format: "%.1f / %.0f GB", usedGB, totalGB)
    }
}

// MARK: - System Status Item

struct SystemStatusItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 11, weight: .medium))
        }
    }
}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(color)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color(nsColor: .controlAccentColor)
                .opacity(0.0001) // 几乎透明，但可以接收点击
        )
        .onHover { hovering in
            // TODO: 添加 hover 效果
        }
    }
}

// MARK: - Plugin Menu Item Row

struct PluginMenuItemRow: View {
    let menuItem: NSMenuItem

    var body: some View {
        Button(action: {
            if let action = menuItem.action {
                _ = menuItem.target?.perform(action, with: menuItem)
            }
        }) {
            HStack(spacing: 12) {
                if let image = menuItem.image {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    Spacer()
                        .frame(width: 24, height: 1)
                }

                Text(menuItem.title)
                    .font(.system(size: 13))

                Spacer()

                let keyEquivalent = menuItem.keyEquivalent
                if !keyEquivalent.isEmpty {
                    Text(keyEquivalent.uppercased())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!menuItem.isEnabled)
    }
}

// MARK: - Preview

#Preview("StatusBar Popup") {
    StatusBarPopupView(
        pluginMenuItems: [],
        onShowMainWindow: {},
        onCheckForUpdates: {},
        onQuit: {}
    )
}
