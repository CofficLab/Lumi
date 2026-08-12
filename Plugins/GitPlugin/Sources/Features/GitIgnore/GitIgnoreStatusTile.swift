import SwiftUI
import LumiUI
import LumiKernel

/// .gitignore 状态磁贴：仅在 .gitignore 缺失时高亮提示。
public struct GitIgnoreStatusTile: View {
    let project: any ProjectProviding
    let onTap: () -> Void
    @State private var exists: Bool = true
    @State private var ruleCount: Int = 0
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
                Image(systemName: exists ? "eye.slash" : "exclamationmark.triangle.fill")
                    .font(.appMicroEmphasized)
                    .foregroundStyle(exists ? theme.textPrimary : theme.warning)
                Text(exists
                     ? "\(ruleCount)"
                     : LumiPluginLocalization.string("Add .gitignore", bundle: .module))
                    .font(.appMicroEmphasized)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string(".gitignore", bundle: .module))
        .task { await refresh() }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        let path = currentProjectPath
        guard !path.isEmpty else { exists = true; ruleCount = 0; return }
        let snapshot = await Task.detached(priority: .userInitiated) {
            (
                exists: GitIgnoreService.exists(forProjectAt: path),
                count:  GitIgnoreService.read(forProjectAt: path)
                    .map { GitIgnoreService.parse($0).count } ?? 0
            )
        }.value
        exists = snapshot.exists
        ruleCount = snapshot.count
    }
}
