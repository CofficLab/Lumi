import LumiUI
import SwiftUI

// MARK: - Manual View

/// Netto 防火墙使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct NettoManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Netto Firewall Plugin"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Netto Firewall: starting and stopping the firewall, setting network permissions for individual apps, and reviewing recent events."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Header: the plugin title, a status badge showing the firewall state, and the Start / Stop button.")),
                .init(L("Apps list: each app with its icon, name, and bundle identifier; the switch on each row controls its network permission.")),
                .init(L("Recent Events list: recent connections with an allowed or denied mark, the address and port, the app, and the time.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Click Start in the header to start the firewall; the status badge shows the current state.")),
                .init(L("In the Apps list, turn on an app's switch to allow its network access, or turn it off to deny it.")),
                .init(L("Review the Recent Events list to check which connections were allowed or denied.")),
                .init(L("Click Stop in the header when you no longer need the firewall.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("When the firewall is stopped, the per-app rules are not enforced.")),
                .init(L("Permission changes take effect immediately while the firewall is running.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 顶部状态栏示意
                HStack(spacing: 8) {
                    lineMock(width: 64)
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.success)
                            .frame(width: 5, height: 5)
                        lineMock(width: 26)
                    }
                    statusPillMock(L("Start"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Rectangle()
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                HStack(spacing: 0) {
                    // ② 应用列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("Apps"))
                        appRowMock()
                        appRowMock()
                        appRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 150, height: 128, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                    Divider()

                    // ③ 最近事件列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("Recent Events"))
                        eventRowMock(allowed: true)
                        eventRowMock(allowed: false)
                        eventRowMock(allowed: true)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 128, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Header"))
                    ManualFigureLegendItem(2, L("Apps"))
                    ManualFigureLegendItem(3, L("Recent Events"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 列表小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 应用行示意:图标 + 两根文字线 + 开关。
    private func appRowMock() -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 44)
                lineMock(width: 32)
            }

            Spacer(minLength: 0)

            toggleMock(on: true)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 事件行示意:允许/拒绝标记 + 地址线 + 时间线。
    private func eventRowMock(allowed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(allowed ? theme.success : theme.error)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 58)
                lineMock(width: 34)
            }

            Spacer(minLength: 0)

            lineMock(width: 20)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 状态栏按钮示意。
    private func statusPillMock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 开关示意。
    private func toggleMock(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.15))
            Circle()
                .fill(Color.primary.opacity(0.5))
                .padding(2)
        }
        .frame(width: 22, height: 12)
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        NettoManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
