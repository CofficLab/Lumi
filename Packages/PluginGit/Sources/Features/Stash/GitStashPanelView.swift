import SwiftUI
import LibGit2Swift
import LumiUI
import KernelLumi

/// 暂存面板视图：列出所有 stash 条目并提供 push / pop / apply / drop / clear。
public struct GitStashPanelView: View {
    let project: any ProjectProviding
    @StateObject private var vm = GitStashViewModel()
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
            inputRow
            Divider()
            if let lastError = vm.lastError {
                Text(lastError)
                    .font(.appCaption)
                    .foregroundStyle(theme.warning)
            }
            if vm.entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task { await vm.refresh() }
        .onChange(of: currentProjectPath) { _, _ in
            vm.projectPath = currentProjectPath
            Task { await vm.refresh() }
        }
        .onApplicationDidBecomeActive {
            Task { await vm.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.primary)
            Text(LumiPluginLocalization.string("Stashes", bundle: .module))
                .font(.appTitle)
            if !vm.entries.isEmpty {
                Text("(\(vm.entries.count))")
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            if vm.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            if !vm.entries.isEmpty {
                Button(role: .destructive) {
                    Task { await vm.clearAll() }
                } label: {
                    Text(LumiPluginLocalization.string("Clear all", bundle: .module))
                        .font(.appCaption)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField(
                LumiPluginLocalization.string("Optional message", bundle: .module),
                text: $vm.pushMessage
            )
            .textFieldStyle(.roundedBorder)
            Button {
                Task { await vm.push() }
            } label: {
                Label(LumiPluginLocalization.string("Stash", bundle: .module),
                      systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentProjectPath.isEmpty)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text(LumiPluginLocalization.string("No stashes yet", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var list: some View {
        VStack(spacing: 6) {
            ForEach(vm.entries) { entry in
                GitStashRow(
                    entry: entry,
                    onPop:    { Task { await vm.pop(index: entry.index) } },
                    onApply:  { Task { await vm.apply(index: entry.index) } },
                    onDrop:   { Task { await vm.drop(index: entry.index) } }
                )
            }
        }
    }
}

private struct GitStashRow: View {
    let entry: GitStashEntry
    let onPop: () -> Void
    let onApply: () -> Void
    let onDrop: () -> Void
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "tray.full.fill")
                .foregroundStyle(theme.primary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text("#\(entry.index) · \(entry.changedFileCount) file(s) · \(entry.date, style: .relative)")
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button(LumiPluginLocalization.string("Pop", bundle: .module), action: onPop)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(LumiPluginLocalization.string("Apply", bundle: .module), action: onApply)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(role: .destructive, action: onDrop) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(LumiPluginLocalization.string("Drop", bundle: .module))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
