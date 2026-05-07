import SwiftUI

// MARK: - AppListRow

/// 可选中的列表行组件，支持 hover 高亮和选中状态
///
/// 扩展了 GlassRow 的能力，增加了 selected 态的视觉反馈。
/// 用于文件树节点、会话项、项目行等可选择的列表项。
///
/// ## 使用示例
/// ```swift
/// AppListRow(
///     isSelected: selectedId == item.id,
///     action: { selectedId = item.id }
/// ) {
///     HStack {
///         Image(systemName: "folder")
///         Text(item.name)
///         Spacer()
///     }
/// }
/// ```
struct AppListRow<Content: View>: View {
    let isSelected: Bool
    let action: (() -> Void)?
    let content: Content

    @State private var isHovered = false

    /// 基础初始化（仅 hover 效果，无选中态）
    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = nil
        self.content = content()
    }

    /// 带点击动作的初始化
    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: { action?() }) {
            content
                .padding(.horizontal, AppUI.Spacing.md)
                .padding(.vertical, AppUI.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rowBackground)
                .overlay(rowBorder)
                .cornerRadius(AppUI.Radius.sm)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        Group {
            if isSelected {
                AppUI.Color.semantic.primary.opacity(0.12)
            } else if isHovered {
                Color.white.opacity(0.08)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .stroke(AppUI.Color.semantic.primary.opacity(0.3), lineWidth: 1)
        } else if isHovered {
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - Preview

#Preview("AppListRow") {
    struct PreviewWrapper: View {
        @State private var selectedId = "item1"
        
        var body: some View {
            VStack(spacing: 4) {
                AppListRow(
                    isSelected: selectedId == "item1",
                    action: { selectedId = "item1" }
                ) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppUI.Color.semantic.primary)
                        Text("项目 A")
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                        Spacer()
                        AppTag("3 个文件", style: .subtle)
                    }
                }
                
                AppListRow(
                    isSelected: selectedId == "item2",
                    action: { selectedId = "item2" }
                ) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                        Text("项目 B")
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                        Spacer()
                    }
                }
                
                AppListRow(isSelected: false) {
                    HStack {
                        Image(systemName: "doc")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                        Text("文档.txt")
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(width: 300)
            .background(AppUI.Color.basePalette.deepBackground)
        }
    }
    return PreviewWrapper()
}