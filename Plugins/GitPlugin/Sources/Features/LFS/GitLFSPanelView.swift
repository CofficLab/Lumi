import SwiftUI
import LumiUI
import KernelLumi

/// LFS 面板：显示跟踪文件数量、远程对象大小并提供 install / fetch / prune。
public struct GitLFSPanelView: View {
    let project: any ProjectProviding
    @StateObject private var vm = GitLFSViewModel()
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
            if !vm.isEnabled {
                notEnabledState
            } else {
                actions
                Divider()
                fileList
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
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.primary)
            Text(LumiPluginLocalization.string("Git LFS", bundle: .module))
                .font(.appTitle)
            if vm.isEnabled {
                Text("(\(vm.trackedFiles.count))")
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

    private var notEnabledState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LumiPluginLocalization.string(
                "Git LFS is not enabled in this repository. Install hooks to enable large file tracking.",
                bundle: .module
            ))
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            Button {
                Task { await vm.install() }
            } label: {
                Label(LumiPluginLocalization.string("Install LFS hooks", bundle: .module),
                      systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await vm.fetch() }
            } label: {
                Label(LumiPluginLocalization.string("Fetch LFS objects", bundle: .module),
                      systemImage: "icloud.and.arrow.down")
            }
            .buttonStyle(.bordered)
            Button {
                Task { await vm.prune() }
            } label: {
                Label(LumiPluginLocalization.string("Prune local cache", bundle: .module),
                      systemImage: "trash")
            }
            .buttonStyle(.bordered)
            Spacer()
            HStack(spacing: 6) {
                TextField("*.psd, *.zip, ...", text: $vm.newPattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                Button(LumiPluginLocalization.string("Track", bundle: .module)) {
                    Task { await vm.addPattern() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var fileList: some View {
        if vm.trackedFiles.isEmpty {
            Text(LumiPluginLocalization.string("No LFS-tracked files yet.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textTertiary)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(vm.trackedFiles) { file in
                        HStack {
                            Image(systemName: "doc")
                                .foregroundStyle(theme.textTertiary)
                            Text(file.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(file.oid)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 280)
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
