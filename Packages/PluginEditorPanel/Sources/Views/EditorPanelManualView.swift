import LumiUI
import SwiftUI

// MARK: - Manual View

/// 代码编辑器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct EditorPanelManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Code Editor"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the built-in Code Editor: browsing and editing project files."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("File sidebar: the list of files in the current project; click a file to open it.")),
                .init(L("Editor area: shows the content of the open file for viewing and editing.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open a project in the app.")),
                .init(L("Select a file in the file sidebar to open it in the editor.")),
                .init(L("Edit the content in the editor area and save the file.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("The editor is provided by the system; if it shows Editor service unavailable, enable the editor-related plugins and restart the app.")),
                .init(L("The editor is available in the rail, the chat, and the panel areas.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 编辑器区域示意

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 文件侧边栏:文件列表示意
                    VStack(alignment: .leading, spacing: 5) {
                        groupLabel(L("Project"))
                        fileRowMock(indent: 0, width: 44)
                        fileRowMock(indent: 1, width: 36, selected: true)
                        fileRowMock(indent: 1, width: 40)
                        fileRowMock(indent: 0, width: 34)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 118, height: 150, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // ② 编辑区:文件名行 + 代码行示意
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            lineMock(width: 36)
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 2)

                        codeLineMock(widths: [56, 74, 48, 84, 62])
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150, alignment: .top)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("File sidebar"))
                    ManualFigureLegendItem(2, L("Editor area"))
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

    /// 文件行示意:缩进 + 一根文字线,选中时高亮。
    private func fileRowMock(indent: CGFloat, width: CGFloat, selected: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc")
                .font(.system(size: 7))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 12, height: 12)
            lineMock(width: width)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .padding(.leading, indent * 10)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(selected ? Color.primary.opacity(0.08) : Color.clear)
        )
    }

    /// 代码行示意:逐行错落的占位线。
    private func codeLineMock(widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 8, alignment: .trailing)
                    lineMock(width: width)
                }
            }
        }
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
        EditorPanelManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif
