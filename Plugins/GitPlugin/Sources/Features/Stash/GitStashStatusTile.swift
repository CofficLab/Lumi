import SwiftUI
import LumiUI
import LumiKernel

/// 状态栏磁贴：在工具栏显示当前 stash 数量。
/// 点击后通过回调打开暂存面板（由宿主 ViewContainer 决定如何呈现）。
public struct GitStashStatusTile: View {
    let project: any ProjectProviding
    let onTap: () -> Void
    @State private var count: Int = 0
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
                Image(systemName: "tray.full")
                    .font(.appMicroEmphasized)
                Text("\(count)")
                    .font(.appMicroEmphasized)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(theme.textPrimary)
            .background(theme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Stashes", bundle: .module))
        .opacity(count == 0 ? 0.45 : 1.0)
        .task { await refresh() }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await refresh() }
        }
        .onApplicationDidBecomeActive {
            Task { await refresh() }
        }
    }

    private func refresh() async {
        let path = currentProjectPath
        guard !path.isEmpty else { count = 0; return }
        let value = await Task.detached(priority: .userInitiated) {
            GitStashService.count(at: path)
        }.value
        count = value
    }
}
