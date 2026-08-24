import LumiUI
import SwiftUI

// MARK: - Manual View

/// App Store Connect 使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct AppStoreConnectManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("AppStoreConnect"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of App Store Connect: configuring credentials, browsing apps and versions, managing distribution, and viewing Xcode Cloud builds."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Preparation"))
            ManualStepList(items: [
                .init(L("Create an API key for App Store Connect and download the private key file.")),
                .init(L("In the Account page, fill in the Issuer ID, Key ID, and private key.")),
                .init(L("Click Test Connection to verify the credentials, then Save.")),
            ])

            ManualSectionHeader(number: 3, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Sidebar: lists your apps and their versions, with New Version and Refresh buttons on top; each version shows its state, such as Ready or Prepare.")),
                .init(L("Account page: enter the Issuer ID, Key ID, and private key; provides Save, Test Connection, and Disconnect, plus a setup guide.")),
                .init(L("Apps page: search and load your apps.")),
                .init(L("Distribution page: edit metadata, import screenshots, view builds, and submit a version for review.")),
                .init(L("Xcode Cloud page: view products and build runs, and enable or disable workflows.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 4, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Configure the credentials in the Account page and test the connection.")),
                .init(L("Open the Apps page and click Load Apps.")),
                .init(L("Select an app in the sidebar to view its versions.")),
                .init(L("Choose a version to edit its distribution, or open the Xcode Cloud page to check its builds.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Keep the private key safe and do not share it.")),
                .init(L("The key must have sufficient permissions; contact your account admin if data fails to load.")),
                .init(L("Click Refresh if the sidebar or a page looks out of date.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 侧边栏:应用与版本列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 5) {
                            toolbarPill("plus")
                            toolbarPill("arrow.clockwise")
                        }

                        groupLabel(L("Apps"))
                        versionRowMock(state: .ready)
                        versionRowMock(state: .prepare)
                        versionRowMock(state: .ready)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 150, height: 168, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // ② 页面区域
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            lineMock(width: 40)
                            Spacer(minLength: 0)
                            toolbarPill("arrow.clockwise")
                        }

                        fieldRowMock()
                        fieldRowMock()

                        HStack(spacing: 5) {
                            actionPillMock()
                            actionPillMock()
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: 168)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Sidebar"))
                    ManualFigureLegendItem(2, L("Page Content"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 侧边栏分组小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 版本行示意:状态点 + 两根文字线。
    private func versionRowMock(state: ReadyState) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state == .ready ? Color.green.opacity(0.7) : Color.orange.opacity(0.7))
                .frame(width: 5, height: 5)
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 52)
                lineMock(width: 34)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private enum ReadyState {
        case ready
        case prepare
    }

    /// 表单字段行示意。
    private func fieldRowMock() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            lineMock(width: 36)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 120, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
        }
    }

    /// 操作按钮示意。
    private func actionPillMock() -> some View {
        lineMock(width: 30)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.primary.opacity(0.15))
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
        AppStoreConnectLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        AppStoreConnectManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
