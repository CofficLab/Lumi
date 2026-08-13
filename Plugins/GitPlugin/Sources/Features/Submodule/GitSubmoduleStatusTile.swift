import SwiftUI
import LumiUI
import KernelLumi

/// Submodule 状态磁贴：显示子模块数量，状态颜色反映是否有未初始化项。
public struct GitSubmoduleStatusTile: View {
    let project: any ProjectProviding
    let onTap: () -> Void
    @State private var count: Int = 0
    @State private var needsAttention: Bool = false
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(project: any ProjectProviding, onTap: @escaping () -> Void) {
        self.project = project
        self.onTap = onTap
    }

    private var currentProjectPath: String {
        project.currentProject?.path ?? ""
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.appMicroEmphasized)
                    .foregroundStyle(needsAttention ? theme.warning : theme.primary)
                Text("\(count)")
                    .font(.appMicroEmphasized)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Submodules", bundle: .module))
        .opacity(count == 0 ? 0.45 : 1.0)
        .task { await refresh() }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        let path = currentProjectPath
        guard !path.isEmpty else { count = 0; needsAttention = false; return }
        let list = await Task.detached(priority: .userInitiated) {
            GitSubmoduleService.list(at: path)
        }.value
        count = list.count
        needsAttention = list.contains { $0.status != .initialized }
    }
}
