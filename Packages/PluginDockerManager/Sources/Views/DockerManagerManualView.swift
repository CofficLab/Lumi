import LumiUI
import SwiftUI

// MARK: - Manual View

/// Docker 镜像管理使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct DockerManagerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Docker"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the Docker image manager: pulling, inspecting, tagging, exporting, and deleting images."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Image list: the sidebar with a search field, a sort menu, and a Refresh button; the footer shows the image count with Import and Pull buttons.")),
                .init(L("Detail area: shows the selected image with its tag and ID, the Security Scan section, and the History / Layers list.")),
                .init(L("Context menu: right-click an image to tag, export, scan, or delete it.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Click Pull in the footer, enter an image reference such as nginx:latest, and confirm.")),
                .init(L("Use the search field and the sort menu to find images by name, size, or creation time.")),
                .init(L("Select an image to view its details, layers, and history.")),
                .init(L("Right-click an image and choose Scan to run a security scan.")),
                .init(L("Right-click an image and choose Tag... or Export... to retag it or save it as a file.")),
                .init(L("Click Delete and confirm to remove the image; this action cannot be undone.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Docker must be running on this Mac; start it and click Refresh if the list is empty or an error is shown.")),
                .init(L("Confirm that no containers depend on an image before deleting it.")),
                .init(L("Import loads a previously exported image file back into the local image list.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 镜像列表:搜索 + 排序 + 列表 + 底部导入/拉取
                    VStack(spacing: 0) {
                        VStack(spacing: 6) {
                            searchMock()
                            HStack(spacing: 5) {
                                toolbarPill("arrow.up.arrow.down")
                                toolbarPill("arrow.clockwise")
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(8)
                        .overlay(alignment: .top) { ManualFigureMarker(1).offset(y: -9) }

                        VStack(alignment: .leading, spacing: 5) {
                            imageRowMock()
                            imageRowMock(selected: true)
                            imageRowMock()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                        Divider()

                        HStack(spacing: 5) {
                            lineMock(width: 26)
                            Spacer(minLength: 0)
                            toolbarPill("square.and.arrow.down")
                            toolbarPill("arrow.down.circle")
                        }
                        .padding(8)
                    }
                    .frame(width: 148, height: 176, alignment: .top)

                    Divider()

                    // ② 详情区:标题 + 操作按钮 + 层历史
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 3) {
                                lineMock(width: 52)
                                lineMock(width: 64)
                            }
                            Spacer(minLength: 0)
                            toolbarPill("shield")
                            toolbarPill("trash")
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            lineMock(width: 70)
                            lineMock(width: 88)
                            lineMock(width: 78)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )

                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 3) {
                            layerRowMock()
                            layerRowMock()
                            layerRowMock()
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 176, alignment: .top)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Image list"))
                    ManualFigureLegendItem(2, L("Detail area"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 搜索框示意。
    private func searchMock() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 7))
                .foregroundStyle(theme.textSecondary)
            lineMock(width: 46)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 镜像行示意:图标 + 名称 + 尺寸标签。
    private func imageRowMock(selected: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "cube")
                .font(.system(size: 7))
                .foregroundStyle(theme.info)
            VStack(alignment: .leading, spacing: 2) {
                lineMock(width: 52)
                lineMock(width: 30)
            }
            Spacer(minLength: 0)
            lineMock(width: 18)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(selected ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
        )
    }

    /// 层历史行示意:短哈希 + 命令行 + 尺寸。
    private func layerRowMock() -> some View {
        HStack(spacing: 5) {
            lineMock(width: 20)
            lineMock(width: 80)
            Spacer(minLength: 0)
            lineMock(width: 16)
        }
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

#if DEBUG
#Preview {
    ScrollView {
        DockerManagerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif
