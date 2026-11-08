import LumiUI
import SwiftUI

// MARK: - Manual View

/// 喝水提醒使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `DocsViewProviding` 的 manual 条目暴露,
/// 在 设置 → 通用 → 说明书 中阅读。
struct HydrationManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Hydration"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Hydration reminder: starting and stopping the reminder, choosing a drink interval, and managing custom intervals."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Start / Stop: the control button in the popover header. It shows the next action, so it reads Stop while the reminder is running.")),
                .init(L("Status: the reminder state, the time until the next break, and today's break count.")),
                .init(L("Interval: a strip of interval buttons for choosing how often the reminder fires.")),
                .init(L("Notification warning: appears when notifications are disabled, with a link to System Settings.")),
                .init(L("Settings page: under Reminder Intervals, the built-in intervals, the add-custom field, and the reset button.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the menu-bar popover and click Start to begin the reminder.")),
                .init(L("Pick an interval under Interval to change how often the reminder fires; the change takes effect immediately.")),
                .init(L("Click Stop to end the reminder and clear the countdown.")),
                .init(L("When the interval elapses, a full-screen gradient appears over the desktop for a few seconds, then fades out on its own.")),
            ])

            ManualSectionHeader(number: 4, title: L("Reminder Behavior"))
            ManualBulletList(items: [
                .init(L("The reminder counts down continuously while it is running and shows the remaining time in the Status area.")),
                .init(L("The break overlay shows a hint to drink some water; it fades out automatically and needs no confirmation.")),
                .init(L("The break counter resets each day and records how many breaks have been taken today.")),
            ])

            ManualSectionHeader(number: 5, title: L("Custom Intervals"))
            ManualStepList(items: [
                .init(L("Open Settings and go to the Hydration page.")),
                .init(L("Enter a positive number of minutes in the Add Custom field and click the add button, or press Return.")),
                .init(L("The new interval appears in the list and is marked as a custom interval.")),
                .init(L("Click the delete button next to a custom interval to remove it. Built-in intervals cannot be deleted.")),
                .init(L("Click Reset to restore the built-in intervals and drop all custom ones.")),
            ])

            ManualSectionHeader(number: 6, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The break overlay is a non-interactive window; it does not block the mouse or the keyboard.")),
                .init(L("If the notification permission is denied, the popover shows a warning with a button that opens System Settings.")),
                .init(L("Removing an interval that is currently selected falls back to the first built-in interval.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Status-bar popover layout")) {
            VStack(alignment: .leading, spacing: 10) {
                // ① 头部与控制按钮
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.primary)
                    Text(L("Hydration"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8))
                        Text(L("Stop"))
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primary.opacity(0.12))
                    )
                    .foregroundStyle(theme.primary)
                }

                Divider()

                // ② 状态区
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Status"))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)

                    HStack {
                        Text(L("Next break: %lld mins", 12))
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(L("Today: %lld breaks", 3))
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Divider()

                // ③ 间隔区
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Interval"))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)

                    HStack(spacing: 5) {
                        ForEach([L("%lld min", 10), L("%lld min", 30), L("%lld hr", 1)], id: \.self) { title in
                            Text(title)
                                .font(.system(size: 9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.primary.opacity(0.12))
                                )
                                .foregroundStyle(theme.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Localization

    /// 取本插件资源表中的文案；查不到时回退为 key 本身。
    ///
    /// 用 `Bundle.module.localizedString` 而非 `String(localized:)`：后者的
    /// `LocalizationValue` 需要编译期字面量，动态 key 取不到条目。
    private func L(_ key: String, _ value: Int) -> String {
        String(
            format: Bundle.module.localizedString(forKey: key, value: key, table: "HydrationReminder"),
            value
        )
    }

    private func L(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: "HydrationReminder")
    }
}

#if DEBUG
#Preview {
    ScrollView {
        HydrationManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif
