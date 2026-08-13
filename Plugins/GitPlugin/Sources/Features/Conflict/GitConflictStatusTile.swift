import SwiftUI
import LumiUI
import KernelLumi

/// 冲突状态磁贴：只在存在冲突时显示。
public struct GitConflictStatusTile: View {
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
        Group {
            if count > 0 {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.appMicroEmphasized)
                            .foregroundStyle(theme.warning)
                        Text("\(count)")
                            .font(.appMicroEmphasized)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.warning.opacity(0.18))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Merge conflicts", bundle: .module))
            }
        }
        .task { await refresh() }
        .onChange(of: currentProjectPath) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        let path = currentProjectPath
        guard !path.isEmpty else { count = 0; return }
        let conflicts = await GitConflictService.listConflicts(at: path)
        count = conflicts.count
    }
}
