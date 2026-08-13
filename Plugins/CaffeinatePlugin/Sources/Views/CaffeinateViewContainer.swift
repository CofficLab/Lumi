import LumiUI
import SwiftUI
import LocalizationKit
import KernelLumi
import SuperLogKit

/// Caffeinate 插件的 ActivityBar 视图容器
///
/// 在 `CaffeinatePlugin.viewContainers(kernel:)` 中注册。用户从 ActivityBar
/// 点击咖啡图标进入此面板，可：
/// - 查看当前 caffeinate 实时状态（活跃 / 已运行时长 / 当前模式）
/// - 配置「启动时默认模式」开关，开启后下次激活自动套用上次偏好
///
/// 详细的「时长 / 快捷操作」仍在 `CaffeinateMenuBarPopupView`（状态栏弹窗）里提供。
struct CaffeinateViewContainer: View, SuperLog {
    let kernel: KernelLumi

    // MARK: - Constants

    /// ViewContainer 内容里的可视刷新间隔（1s），用来刷新「已运行多久」。
    private static let refreshInterval: TimeInterval = 1.0

    // MARK: - State

    @State private var manager = CaffeinateManager.shared

    /// 「使用默认模式」开关的本地状态。
    ///
    /// - true：激活时使用 `persistedDefaultMode`（用户上次选择）；
    /// - false：恢复运行时按上次调用方传入的 mode（不持久化偏好）。
    @State private var enableDefaultMode: Bool = CaffeinateManager.shared.persistedDefaultMode != nil

    /// 实际生效的默认模式；只在启用开关为 true 时被持久化。
    @State private var defaultMode: CaffeinateManager.SleepMode =
        CaffeinateManager.shared.persistedDefaultMode ?? .systemAndDisplay

    /// 触发状态卡重新计算已运行时长。
    @State private var elapsedTick: Date = .init()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusCard
                defaultModeCard
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .onAppear {
            manager.configure(kernel: kernel)
            syncFromPersisted()
        }
        .onReceive(Timer.publish(every: Self.refreshInterval, on: .main, in: .common).autoconnect()) { date in
            elapsedTick = date
        }
    }

    // MARK: - Status Card

    /// 实时状态卡：是否激活、当前模式、（如激活）已运行时长。
    private var statusCard: some View {
        AppCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                Text(LumiPluginLocalization.string("Status", bundle: .module))
                    .font(.appSectionTitle)
                    .foregroundStyle(.primary)

                HStack(spacing: 14) {
                    statusIndicator
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(.appTitle)
                            .foregroundStyle(.primary)
                        Text(statusSubtitle)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if manager.isActive {
                    Divider()
                    HStack(spacing: 24) {
                        statusStat(
                            title: LumiPluginLocalization.string("Mode", bundle: .module),
                            value: manager.mode.displayName
                        )
                        statusStat(
                            title: LumiPluginLocalization.string("Elapsed", bundle: .module),
                            value: formattedElapsed
                        )
                    }
                }
            }
        }
    }

    private var statusIndicator: some View {
        let isActive = manager.isActive
        return Image(systemName: isActive ? "checkmark.circle.fill" : "moon.zzz")
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(isActive ? Color.green : Color.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    private var statusTitle: String {
        manager.isActive
            ? LumiPluginLocalization.string("Caffeinate is active", bundle: .module)
            : LumiPluginLocalization.string("Caffeinate is idle", bundle: .module)
    }

    private var statusSubtitle: String {
        manager.isActive
            ? LumiPluginLocalization.string(
                "Your Mac will stay awake until deactivated or the timer expires.",
                bundle: .module
            )
            : LumiPluginLocalization.string(
                "Open the menu bar popup to choose a duration and start caffeinating.",
                bundle: .module
            )
    }

    private func statusStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.appBody)
                .foregroundStyle(.primary)
        }
    }

    /// 「已运行时长」的可读格式，例如 `00:01:23`；未激活时显示占位符。
    private var formattedElapsed: String {
        guard manager.isActive, let start = manager.startTime else { return "—" }
        _ = elapsedTick // 触发 SwiftUI 重新求值
        let seconds = max(0, Int(Date().timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    // MARK: - Default Mode Card

    /// 「启动时默认模式」配置卡：一个 Toggle + 一个分段选择器。
    private var defaultModeCard: some View {
        AppCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                Text(LumiPluginLocalization.string("Default Mode", bundle: .module))
                    .font(.appSectionTitle)
                    .foregroundStyle(.primary)

                Toggle(
                    LumiPluginLocalization.string(
                        "Use a default mode when caffeinating",
                        bundle: .module
                    ),
                    isOn: $enableDefaultMode
                )
                .toggleStyle(.switch)
                .onChange(of: enableDefaultMode) { _, newValue in
                    persistDefaultModeChange(enabled: newValue, mode: defaultMode)
                }

                if enableDefaultMode {
                    Picker(
                        LumiPluginLocalization.string("Mode", bundle: .module),
                        selection: $defaultMode
                    ) {
                        ForEach(CaffeinateManager.SleepMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: defaultMode) { _, newValue in
                        persistDefaultModeChange(enabled: enableDefaultMode, mode: newValue)
                    }

                    Text(LumiPluginLocalization.string(
                        "This mode will be applied automatically when you activate caffeinate.",
                        bundle: .module
                    ))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    /// 从 `CaffeinateManager.persistedDefaultMode` 同步本地 State。
    ///
    /// 在 `onAppear` 调用一次，避免视图首次渲染时与持久化值不一致。
    private func syncFromPersisted() {
        if let stored = manager.persistedDefaultMode {
            enableDefaultMode = true
            defaultMode = stored
        } else {
            enableDefaultMode = false
        }
    }

    /// 持久化用户选择：
    /// - Toggle 关闭时清除持久化偏好；
    /// - Toggle 开启时把当前 `mode` 写入 LocalStore。
    private func persistDefaultModeChange(enabled: Bool, mode: CaffeinateManager.SleepMode) {
        let valueToStore: CaffeinateManager.SleepMode? = enabled ? mode : nil
        let success = manager.setPersistedDefaultMode(valueToStore)
        if CaffeinatePlugin.verbose {
            CaffeinatePlugin.logger.info(
                "\(self.t)persistDefaultModeChange enabled=\(enabled) mode=\(mode.rawValue) success=\(success)"
            )
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    CaffeinateViewContainer(kernel: KernelLumi())
        .frame(width: 520, height: 360)
}

#Preview("With Default Mode Enabled") {
    CaffeinateViewContainer(kernel: KernelLumi())
        .frame(width: 520, height: 360)
        .onAppear {
            CaffeinateLocalStore.shared.setDefaultModeRaw(
                CaffeinateManager.SleepMode.systemAndDisplay.rawValue
            )
        }
}