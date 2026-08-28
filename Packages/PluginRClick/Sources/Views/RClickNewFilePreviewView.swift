import SwiftUI
import LumiUI

/// 新建文件子菜单展开预览
///
/// 突出显示二级菜单（新建文件子菜单），下方用缩小的一级菜单作为上下文参考，
/// 模拟真实 macOS 子菜单弹出效果。
public struct RClickNewFilePreviewView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let config: RClickConfig

    private var enabledTemplates: [NewFileTemplate] {
        config.fileTemplates.filter { $0.isEnabled }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 二级菜单（突出显示，正常大小）
            if !enabledTemplates.isEmpty {
                submenuPanel
            }

            // 一级菜单（缩小作为上下文参考）
            primaryMenuCompact
        }
    }

    // MARK: - Submenu Panel (Primary Focus)

    private var submenuPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(enabledTemplates.enumerated()), id: \.element.id) { index, template in
                if index > 0 {
                    Spacer().frame(height: 2)
                }
                templateRow(template)
            }
        }
        .padding(6)
        .frame(width: 180)
        .appSurface(
            style: .glass,
            cornerRadius: 8,
            borderColor: Color.white.opacity(0.12),
            lineWidth: 0.5
        )
    }

    // MARK: - Primary Menu (Compact Context)

    private var primaryMenuCompact: some View {
        VStack(spacing: 0) {
            ForEach(config.items) { item in
                if item.isEnabled {
                    if item.type == .newFile {
                        newFileRowCompact(item)
                    } else {
                        previewMenuRowCompact(item)
                    }
                }
            }
        }
        .padding(4)
        .frame(width: 140)
        .scaleEffect(0.85)
        .frame(width: 140 * 0.85) // 调整 frame 以匹配缩小后的实际宽度
        .appSurface(
            style: .glass,
            cornerRadius: 6,
            borderColor: Color.white.opacity(0.08),
            lineWidth: 0.5
        )
        .opacity(0.75) // 降低透明度，突出二级菜单
    }

    // MARK: - Compact New File Row

    private func newFileRowCompact(_ item: RClickMenuItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 10))
                .frame(width: 12)
                .foregroundColor(theme.primary)

            Text(item.title)
                .font(.system(size: 10))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(theme.primary)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.primary.opacity(0.15))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Compact Preview Menu Row

    private func previewMenuRowCompact(_ item: RClickMenuItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 10))
                .frame(width: 12)
                .foregroundColor(theme.textSecondary)

            Text(item.title)
                .font(.system(size: 10))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Template Row (Normal Size)

    private func templateRow(_ template: NewFileTemplate) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.appCallout)
                .frame(width: 16)
                .foregroundColor(theme.textSecondary)

            Text("\(template.name) (.\(template.extensionName))")
                .font(.appCallout)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("New File Submenu") {
    RClickNewFilePreviewView(config: .default)
        .inRootView()
}
