import KitPrototype
import LumiUI
import SwiftUI

/// Rail 中的单个屏幕行：点击选中，context menu 提供删除。
struct PrototypeScreenRowView: View {
    @ObservedObject var workspace: WorkspaceStore
    @LumiTheme private var theme
    let project: PrototypeProject
    let screen: PrototypeScreen

    // MARK: - 初始化

    init(workspace: WorkspaceStore, project: PrototypeProject, screen: PrototypeScreen) {
        self.workspace = workspace
        self.project = project
        self.screen = screen
    }

    // MARK: - Body

    var body: some View {
        // 菜单挂在 row 上：放进 AppListRow 的 Button label 会被按钮吞掉右键事件。
        AppListRow(isSelected: isSelected, action: {
            workspace.select(projectID: project.id, screenID: screen.id)
        }) {
            HStack(spacing: 8) {
                Text("\(screen.order + 1)")
                    .font(.appMonoMicro)
                    .foregroundStyle(theme.textTertiary)
                Text(screen.title)
                    .font(.appMicroEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if screen.hotspots.isEmpty == false {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                if isStartScreen {
                    AppTag(PrototypeLocalization.string("Start"), style: .accent)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                workspace.deleteScreen(projectID: project.id, screenID: screen.id)
            } label: {
                Label(PrototypeLocalization.string("Delete Screen"), systemImage: "trash")
            }
        }
    }

    // MARK: - 计算属性

    private var isSelected: Bool {
        workspace.selectedProjectID == project.id
            && workspace.selectedScreenID == screen.id
    }

    private var isStartScreen: Bool {
        project.resolvedStartScreen?.id == screen.id
    }
}

// MARK: - 预览

#Preview {
    let project = PrototypeProject(
        id: "preview",
        title: "Checkout Flow",
        style: .wireframe,
        device: PrototypeDeviceKind.iPhone15Pro.preset!,
        screens: [PrototypeScreen(id: "01-home", title: "首页", order: 0)]
    )
    VStack(alignment: .leading) {
        PrototypeScreenRowView(
            workspace: WorkspaceStore.shared,
            project: project,
            screen: project.screens[0]
        )
    }
    .frame(width: 280)
    .background(Color(nsColor: .controlBackgroundColor))
}
