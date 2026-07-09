import SwiftUI
import LumiUI

/// 文件树节点行视图（精简版）
///
/// 仅负责视觉渲染，不包含任何交互修饰符。
/// 所有交互逻辑由 NSCollectionViewDelegate 处理。
struct NodeRowView: View {
    let item: FileTreeNodeItem
    let isSelected: Bool
    let isHovered: Bool
    let gitStatus: GitStatus?
    let theme: any LumiAppChromeTheme
    let flashOpacity: Double

    var body: some View {
        HStack(spacing: 4) {
            // 展开/折叠箭头
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.workspaceTertiaryTextColor())
                    .frame(width: 12)
                    .rotationEffect(.degrees(item.isExpanded ? 90 : 0))
            } else {
                Color.clear.frame(width: 12)
            }

            // 文件图标
            fileIconView(item)
                .font(.system(size: 12))
                .foregroundColor(item.isDirectory ? theme.workspaceTextColor() : theme.workspaceSecondaryTextColor())
                .frame(width: 16)

            // 文件名
            Text(item.fileName)
                .font(.appCaption)
                .foregroundColor(theme.workspaceTextColor())
                .lineLimit(1)

            Spacer()

            // Git 状态标记（预留位置）
            if let gitStatus = gitStatus {
                Text(gitStatus.displayLetter)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(gitStatusColor(gitStatus, isSelected: isSelected))
                    .frame(width: 16, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, CGFloat(item.depth) * 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground())
    }

    private func fileIconView(_ item: FileTreeNodeItem) -> Image {
        let context = LumiFileIconContext(
            url: item.url,
            fileName: item.iconMetadata.fileName,
            fileExtension: item.iconMetadata.fileExtension,
            isDirectory: item.iconMetadata.isDirectory,
            isExpanded: item.isExpanded,
            isSwiftPackageDirectory: item.iconMetadata.isSwiftPackageDirectory,
            projectRootPath: ""
        )
        let icon = LumiDefaultFileIconThemeContributor().icon(for: context)
        switch icon {
        case .systemImage(let name):
            return Image(systemName: name)
        case .assetImage(let name, _):
            return Image(name)
        case nil:
            return Image(systemName: item.isDirectory ? "folder" : "doc")
        }
    }

    private func rowBackground() -> some View {
        ZStack(alignment: .leading) {
            if isSelected {
                theme.sidebarSelectionColor()
            } else if isHovered {
                theme.workspaceTextColor().opacity(0.06)
            } else {
                Color.clear
            }
            // 闪烁高亮覆盖层
            if flashOpacity > 0 {
                Color.accentColor.opacity(flashOpacity)
            }
        }
    }

    private func gitStatusColor(_ status: GitStatus, isSelected: Bool) -> Color {
        let base: Color = switch status {
        case .modified: .orange
        case .added, .untracked: .green
        case .deleted: .red
        case .renamed: .purple
        case .staged: .orange.opacity(0.7)
        case .conflicted: .red
        }
        return isSelected ? base.opacity(0.9) : base.opacity(0.7)
    }
}

extension NodeRowView {
    static var placeholder: Self {
        let placeholderURL = URL(fileURLWithPath: "/placeholder")
        return NodeRowView(
            item: FileTreeNodeItem(
                url: placeholderURL, depth: 0, isDirectory: false,
                isExpanded: false, projectRootPath: ""
            ),
            isSelected: false, isHovered: false,
            gitStatus: nil,
            theme: LumiFallbackChromeTheme(),
            flashOpacity: 0
        )
    }
}
