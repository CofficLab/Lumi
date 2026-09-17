import KitPrototype
import LumiUI
import SwiftUI

/// Rail 中的原型项目节点：可展开展示其下所有屏幕，点击标题选中项目。
struct PrototypeTreeView: View {
    @ObservedObject var workspace: WorkspaceStore
    @LumiTheme private var theme
    @Binding var isExpanded: Bool
    let project: PrototypeProject

    // MARK: - 初始化

    init(
        workspace: WorkspaceStore,
        isExpanded: Binding<Bool>,
        project: PrototypeProject
    ) {
        self.workspace = workspace
        self._isExpanded = isExpanded
        self.project = project
    }

    // MARK: - Body

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if project.screens.isEmpty {
                Text(PrototypeLocalization.string("No screens yet"))
                    .font(.footnote)
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
            } else {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(project.sortedScreens) { screen in
                        PrototypeScreenRowView(
                            workspace: workspace,
                            project: project,
                            screen: screen
                        )
                    }
                }
                .padding(.leading, DesignTokens.Spacing.sm)
            }
        } label: {
            projectHeader
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var projectHeader: some View {
        // 菜单挂在 row 上，避免被 AppListRow 的 Button 吞掉右键事件。
        AppListRow(isSelected: isSelected, action: {
            workspace.select(projectID: project.id, screenID: project.resolvedStartScreen?.id)
            isExpanded = true
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundStyle(theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    // 由已本地化片段与数据拼成的摘要，不走 LocalizedStringKey，
                    // 否则会被当作待翻译字符串提取出无意义的插值 key。
                    Text(verbatim: "\(project.screens.count) \(PrototypeLocalization.string("screens")) · \(project.style.rawValue) · \(project.device.kind.displayName)")
                        .font(.footnote)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                workspace.deleteProject(id: project.id)
            } label: {
                Label(PrototypeLocalization.string("Delete Prototype"), systemImage: "trash")
            }
        }
    }

    // MARK: - 计算属性

    private var isSelected: Bool {
        workspace.selectedProjectID == project.id
    }
}

// MARK: - 预览

#Preview {
    let project = PrototypeProject(
        id: "preview",
        title: "Checkout Flow",
        style: .wireframe,
        device: PrototypeDeviceKind.iPhone15Pro.preset!,
        screens: [
            PrototypeScreen(id: "01-home", title: "首页", order: 0),
            PrototypeScreen(id: "02-detail", title: "详情", order: 1),
        ]
    )
    StatefulPreviewWrapper(true) { binding in
        PrototypeTreeView(
            workspace: WorkspaceStore.shared,
            isExpanded: binding,
            project: project
        )
    }
    .frame(width: 300)
    .background(Color(nsColor: .controlBackgroundColor))
}

/// 仅用于预览：为绑定提供可写状态。
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
