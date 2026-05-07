import SwiftUI

// MARK: - AppContextMenuRow

/// 上下文菜单行组件
///
/// 用于构建右键菜单的菜单项，提供统一的图标 + 标题 + 快捷键样式。
/// 与 SwiftUI 原生 contextMenu 配合使用。
///
/// ## 使用示例
/// ```swift
/// .contextMenu {
///     AppContextMenuRow("在 Finder 中显示", systemImage: "finder") {
///         // 打开 Finder
///     }
///
///     AppContextMenuRow("在 VS Code 中打开", systemImage: "chevron.left.forwardslash.chevron.right") {
///         // 打开 VS Code
///     }
///
///     Divider()
///
///     AppContextMenuRow("删除", systemImage: "trash", role: .destructive) {
///         // 删除
///     }
/// }
/// ```
struct AppContextMenuRow: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void

    /// 普通菜单项
    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = nil
        self.action = action
    }

    /// 带角色的菜单项（如 destructive）
    init(_ title: LocalizedStringKey, systemImage: String? = nil, role: ButtonRole, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
    }
}

// MARK: - Preview

#Preview("AppContextMenuRow") {
    VStack(spacing: 16) {
        Text("右键点击查看菜单")
            .padding(40)
            .background(AppUI.Material.glass)
            .cornerRadius(8)
            .contextMenu {
                AppContextMenuRow("在 Finder 中显示", systemImage: "finder") {
                    print("打开 Finder")
                }

                AppContextMenuRow("在 VS Code 中打开", systemImage: "chevron.left.forwardslash.chevron.right") {
                    print("打开 VS Code")
                }

                AppContextMenuRow("在终端中打开", systemImage: "terminal") {
                    print("打开终端")
                }

                Divider()

                AppContextMenuRow("删除", systemImage: "trash", role: .destructive) {
                    print("删除")
                }
            }
    }
    .padding()
    .frame(width: 400, height: 200)
    .background(AppUI.Color.basePalette.deepBackground)
}