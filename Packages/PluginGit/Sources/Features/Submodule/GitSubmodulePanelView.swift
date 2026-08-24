import SwiftUI
import LumiUI
import KernelLumi
import LibGit2Swift

/// Submodule 面板。
public struct GitSubmodulePanelView: View {
    let project: any ProjectProviding
    @StateObject private var vm = GitSubmoduleViewModel()
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
            actions
            Divider()
            if vm.submodules.isEmpty {
                emptyState
            } else {
                list
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
        .onApplicationDidBecomeActive {
            Task { await vm.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.gearshape")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.primary)
            Text(LumiPluginLocalization.string("Submodules", bundle: .module))
                .font(.appTitle)
            if !vm.submodules.isEmpty {
                Text("(\(vm.submodules.count))")
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

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await vm.initializeAll() }
            } label: {
                Label(LumiPluginLocalization.string("Init all", bundle: .module),
                      systemImage: "wrench.adjustable")
            }
            .buttonStyle(.bordered)
            Button {
                Task { await vm.updateAll(initialize: true) }
            } label: {
                Label(LumiPluginLocalization.string("Update all", bundle: .module),
                      systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text(LumiPluginLocalization.string("No submodules in this repository.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var list: some View {
        VStack(spacing: 6) {
            ForEach(vm.submodules, id: \.path) { sub in
                row(for: sub)
            }
        }
    }

    private func row(for sub: GitSubmoduleInfo) -> some View {
        HStack(alignment: .center, spacing: 10) {
            statusIcon(for: sub.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.path)
                    .font(.appCaptionEmphasized)
                Text(sub.commitHash.prefix(8) + " · " + (sub.description ?? "—"))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button(LumiPluginLocalization.string("Update", bundle: .module)) {
                Task { await vm.updateOne(sub.path) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusIcon(for status: GitSubmoduleInfo.Status) -> some View {
        let (icon, color) = switch status {
        case .initialized:   ("checkmark.circle.fill", theme.success)
        case .uninitialized: ("questionmark.circle.fill", theme.textTertiary)
        case .modified:      ("exclamationmark.circle.fill", theme.warning)
        case .conflicted:    ("xmark.octagon.fill", theme.warning)
        }
        return Image(systemName: icon).foregroundStyle(color)
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
