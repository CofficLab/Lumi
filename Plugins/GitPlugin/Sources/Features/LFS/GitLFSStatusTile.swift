import SwiftUI
import LumiUI
import LumiKernel

/// LFS 状态磁贴：显示当前仓库是否启用了 LFS。
public struct GitLFSStatusTile: View {
    let project: any ProjectProviding
    let onTap: () -> Void
    @State private var isEnabled: Bool = false
    @State private var fileCount: Int = 0
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
                Image(systemName: isEnabled ? "externaldrive" : "externaldrive.badge.questionmark")
                    .font(.appMicroEmphasized)
                    .foregroundStyle(isEnabled ? theme.primary : theme.textTertiary)
                Text(isEnabled ? "LFS \(fileCount)" : "LFS")
                    .font(.appMicroEmphasized)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Git LFS", bundle: .module))
        .opacity(isEnabled ? 1.0 : 0.55)
        .task { await refresh() }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        let path = currentProjectPath
        guard !path.isEmpty else { isEnabled = false; fileCount = 0; return }
        let enabled = await GitLFSService.isEnabled(at: path)
        let count = enabled ? await GitLFSService.listTracked(at: path).count : 0
        isEnabled = enabled
        fileCount = count
    }
}
