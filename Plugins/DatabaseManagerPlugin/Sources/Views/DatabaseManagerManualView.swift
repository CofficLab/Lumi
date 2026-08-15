import LumiUI
import SwiftUI

// MARK: - Manual View

/// 数据库管理器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct DatabaseManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Database"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Database Manager: managing connections, browsing tables, and running SQL."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Sidebar: two modes via the switch at the top. Connections lists saved connections; Tables shows the object tree of the connected database with a filter.")),
                .init(L("Main area: the SQL editor with Run All and History buttons, the query results below, and an inspector for table structure.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Database tab in the sidebar.")),
                .init(L("In Connections, click + to add a connection, fill in the database type, name, and password, then save and connect.")),
                .init(L("Switch to Tables to browse the object tree and inspect a table's structure.")),
                .init(L("Write SQL in the editor and click Run All; the results appear below.")),
                .init(L("Open History to review previously run SQL.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Leave the password field empty when editing a connection to keep the saved password.")),
                .init(L("Review write operations carefully before running them; some changes cannot be undone.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 侧边栏:连接 / 表 两种模式
                    VStack(alignment: .leading, spacing: 7) {
                        segmentedMock()
                        treeRowMock(icon: "cylinder")
                        treeRowMock(icon: "cylinder")
                        treeRowMock(icon: "tablecells")
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 128, height: 168, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // 主区域:② SQL 编辑区 + ③ 结果区
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            toolbarPill("play.fill")
                            toolbarPill("clock.arrow.circlepath")
                        }

                        editorMock()
                            .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                        resultMock()
                            .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 168, alignment: .top)
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Sidebar"))
                    ManualFigureLegendItem(2, L("SQL editor"))
                    ManualFigureLegendItem(3, L("Results"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 「连接 / 表」切换示意:两格相连的分段控件。
    private func segmentedMock() -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 30, height: 14)
            Rectangle().fill(Color.clear).frame(width: 30, height: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 侧边栏树行示意。
    private func treeRowMock(icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16, height: 14)
            lineMock(width: 48)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
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

    /// SQL 编辑区示意:若干行代码线。
    private func editorMock() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                lineMock(width: 110)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 查询结果示意:表头 + 三行数据。
    private func resultMock() -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                lineMock(width: 26)
                lineMock(width: 26)
                lineMock(width: 26)
            }
            Divider()
            HStack(spacing: 6) {
                lineMock(width: 20)
                lineMock(width: 30)
                lineMock(width: 22)
            }
            HStack(spacing: 6) {
                lineMock(width: 24)
                lineMock(width: 18)
                lineMock(width: 28)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
        DatabaseManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
