import SwiftUI
import LumiUI

/// 文件树专用的已解析调色板。
///
/// `Color.adaptive` 在 AppKit 的独立 `NSHostingView` 中可能按窗口残留外观再次解析，
/// 造成主题背景与文字走不同明暗分支。这里在 cell 配置时按目标 `NSAppearance`
/// 将动态色转换为固定 sRGB 颜色，后续渲染不再受宿主外观变化影响。
struct FileTreeRowPalette {
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accentPrimary: Color
    let selectionBackground: Color
    let hoverBackground: Color

    init(
        theme: any LumiAppChromeTheme,
        uiTheme: any LumiUITheme,
        appearance: NSAppearance
    ) {
        textPrimary = Self.resolve(theme.workspaceTextColor(), appearance: appearance)
        textSecondary = Self.resolve(theme.workspaceSecondaryTextColor(), appearance: appearance)
        textTertiary = Self.resolve(theme.workspaceTertiaryTextColor(), appearance: appearance)
        accentPrimary = Self.resolve(uiTheme.primary, appearance: appearance)
        selectionBackground = Self.resolve(theme.sidebarSelectionColor(), appearance: appearance)
        hoverBackground = Self.resolve(theme.workspaceTextColor().opacity(0.06), appearance: appearance)
    }

    private static func resolve(_ color: Color, appearance: NSAppearance) -> Color {
        var resolved = NSColor.clear
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        }
        return Color(resolved)
    }
}

/// 文件树节点行视图（精简版）
///
/// 仅负责视觉渲染，不包含任何交互修饰符。
/// 所有交互逻辑由 NSCollectionViewDelegate 处理。
struct NodeRowView: View {
    let item: FileTreeNodeItem
    let isSelected: Bool
    let isHovered: Bool
    let gitStatus: GitStatus?
    let palette: FileTreeRowPalette
    let colorScheme: ColorScheme
    /// 当前外观标识，变化时通过 .id 强制 SwiftUI 销毁重建视图树，绕过 diff 缓存
    let appearanceID: String

    var body: some View {
        HStack(spacing: 4) {
            // 展开/折叠箭头
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(palette.textTertiary)
                    .frame(width: 12)
                    .rotationEffect(.degrees(item.isExpanded ? 90 : 0))
            } else {
                Color.clear.frame(width: 12)
            }

            // 文件图标
            fileIconView(item)
                .font(.system(size: 12))
                .foregroundColor(item.isDirectory ? palette.textPrimary : palette.textSecondary)
                .frame(width: 16)

            // 文件名
            Text(item.fileName)
                .font(.appCaption)
                .foregroundColor(palette.textPrimary)
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
        // NSHostingView 不会可靠继承外层 SwiftUI 的主题环境，必须显式注入。
        .environment(\.colorScheme, colorScheme)
        .id(appearanceID)
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
                palette.selectionBackground
            } else if isHovered {
                palette.hoverBackground
            } else {
                Color.clear
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
            palette: FileTreeRowPalette(
                theme: LumiFallbackChromeTheme(),
                uiTheme: LumiDefaultTheme(),
                appearance: NSAppearance(named: .aqua)!
            ),
            colorScheme: .light,
            appearanceID: "placeholder"
        )
    }
}
