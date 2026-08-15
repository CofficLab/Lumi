import LumiUI
import SwiftUI

// MARK: - Manual View

/// 注册表管理器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct RegistryManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Registry Manager"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Registry Manager: viewing the current registry of each package manager and switching it to a preset mirror."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Card grid: one card per registry type, such as NPM, Yarn, PNPM, Docker, Pip, and Go Proxy.")),
                .init(L("Card header: the registry icon and name, with a refresh button on the right.")),
                .init(L("Current Registry: the registry address in use; click it to copy the address to the clipboard.")),
                .init(L("Switch Source: a menu of preset mirrors; the one in use is marked with a checkmark.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Registry Manager tab; the current registry of each type is read automatically.")),
                .init(L("Click the refresh button on a card to re-read that registry.")),
                .init(L("Click the Current Registry address to copy it; a toast confirms the copy.")),
                .init(L("Choose a mirror from the Switch Source menu to switch the registry.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("A switched registry takes effect for new installations.")),
                .init(L("After switching the Docker registry, restart Docker Desktop.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 卡片网格

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 卡片网格示意
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        registryCardMock(markers: true)
                        registryCardMock()
                    }
                    HStack(spacing: 8) {
                        registryCardMock()
                        registryCardMock()
                    }
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Card Grid"))
                    ManualFigureLegendItem(2, L("Current Registry"))
                    ManualFigureLegendItem(3, L("Switch Source"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 注册表卡片示意:图标 + 名称 + 刷新,当前源地址行,切换来源按钮。
    private func registryCardMock(markers: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.primary.opacity(0.15))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "shippingbox")
                            .font(.system(size: 7))
                            .foregroundStyle(theme.textSecondary)
                    )
                lineMock(width: 30)

                Spacer(minLength: 0)

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textSecondary)
            }

            // ② 当前源地址行
            HStack(spacing: 4) {
                lineMock(width: 70)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
            .overlay(alignment: .topLeading) {
                if markers { ManualFigureMarker(2).padding(-6) }
            }

            // ③ 切换来源按钮
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 7))
                    .foregroundStyle(theme.textSecondary)
                lineMock(width: 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
            .overlay(alignment: .topLeading) {
                if markers { ManualFigureMarker(3).padding(-6) }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
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
        RegistryManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
