import SwiftUI

// MARK: - AppDisclosureCard

/// 可折叠的信息卡片组件
///
/// 封装 DisclosureGroup，提供统一的标题 + 展开/收起样式。
/// 用于详情展示、高级选项等可折叠区域。
///
/// ## 使用示例
/// ```swift
/// AppDisclosureCard(title: "详细信息") {
///     VStack {
///         Text("第一行")
///         Text("第二行")
///     }
/// }
/// ```
struct AppDisclosureCard<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String?
    @ViewBuilder let content: Content

    @State private var isExpanded = false

    /// 基础初始化
    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = nil
        self.content = content()
    }

    /// 带图标的初始化
    init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, AppUI.Spacing.sm)
        } label: {
            HStack(spacing: AppUI.Spacing.sm) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 12)

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(AppUI.Color.semantic.primary)
                }

                Text(title)
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .padding(AppUI.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .fill(AppUI.Material.glass)
        )
    }
}

// MARK: - Preview

#Preview("AppDisclosureCard") {
    VStack(spacing: 16) {
        AppDisclosureCard(title: "详细信息") {
            VStack(alignment: .leading, spacing: 8) {
                Text("名称: 示例项目")
                Text("路径: /Users/example/project")
                Text("大小: 1.5 GB")
            }
            .font(AppUI.Typography.caption1)
            .foregroundColor(AppUI.Color.semantic.textSecondary)
        }

        AppDisclosureCard(title: "高级选项", icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("自动保存", isOn: .constant(true))
                Toggle("显示预览", isOn: .constant(false))
            }
        }
    }
    .padding()
    .frame(width: 400)
    .background(AppUI.Color.basePalette.deepBackground)
}