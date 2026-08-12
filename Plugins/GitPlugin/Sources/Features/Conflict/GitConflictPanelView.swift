import SwiftUI
import LumiUI
import LumiKernel

/// 冲突解决面板：列出未合并文件，并提供 ours / theirs / mark resolved 操作。
public struct GitConflictPanelView: View {
    let project: any ProjectProviding
    @StateObject private var vm = GitConflictViewModel()
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(project: any ProjectProviding) {
        self.project = project
        vm.projectPath = project.currentProject?.path ?? ""
    }

    private var currentProjectPath: String {
        project.currentProject?.path ?? ""
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if vm.hasConflicts {
                list
                footer
            } else {
                emptyState
            }
            messages
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            vm.projectPath = currentProjectPath
            await vm.refresh()
        }
        .onChange(of: currentProjectPath) { _, _ in
            vm.projectPath = currentProjectPath
            Task { await vm.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.warning)
            Text(LumiPluginLocalization.string("Merge Conflicts", bundle: .module))
                .font(.appTitle)
            if !vm.conflicts.isEmpty {
                Text("(\(vm.conflicts.count))")
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            if vm.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await vm.refresh() }
            } label: { Image(systemName: "arrow.clockwise") }
            .buttonStyle(.borderless)
        }
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(theme.success)
            Text(LumiPluginLocalization.string("No active merge conflicts.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 12)
    }

    private var list: some View {
        VStack(spacing: 6) {
            ForEach(vm.conflicts) { conflict in
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "doc.fill.badge.exclamationmark")
                        .foregroundStyle(theme.warning)
                    Text(conflict.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Ours") {
                        Task { await vm.resolve(conflict, with: .ours) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Theirs") {
                        Task { await vm.resolve(conflict, with: .theirs) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button {
                        Task { await vm.resolve(conflict, with: .manual) }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .help(LumiPluginLocalization.string("Mark as resolved", bundle: .module))
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                Task { await vm.abort() }
            } label: {
                Label(LumiPluginLocalization.string("Abort merge", bundle: .module),
                      systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let err = vm.lastError {
            Text(err).font(.appCaption).foregroundStyle(theme.warning)
        }
        if let info = vm.lastInfo {
            Text(info).font(.appCaption).foregroundStyle(theme.success)
        }
    }
}
