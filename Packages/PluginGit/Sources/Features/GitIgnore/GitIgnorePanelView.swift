import SwiftUI
import LumiUI
import KernelLumi

/// .gitignore 编辑面板。
public struct GitIgnorePanelView: View {
    let project: any ProjectProviding
    @StateObject private var vm = GitIgnoreViewModel()
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(project: any ProjectProviding) {
        self.project = project
        vm.projectPath = project.currentProject?.path ?? ""
    }

    private var currentProjectPath: String {
        project.currentProject?.path ?? ""
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            templates
            editor
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            vm.projectPath = currentProjectPath
            await vm.load()
        }
        .onChange(of: currentProjectPath) { _, _ in
            vm.projectPath = currentProjectPath
            Task { await vm.load() }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.primary)
            Text(LumiPluginLocalization.string(".gitignore", bundle: .module))
                .font(.appTitle)
            if !vm.exists {
                Text(LumiPluginLocalization.string("(missing)", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if vm.isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var templates: some View {
        HStack(spacing: 6) {
            Text(LumiPluginLocalization.string("Insert template:", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            ForEach(GitIgnoreService.availableTemplates, id: \.self) { name in
                Button(name) {
                    Task { await vm.insertTemplate(name) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var editor: some View {
        TextEditor(text: $vm.draft)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 240)
            .padding(8)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var footer: some View {
        if let err = vm.lastError {
            Text(err)
                .font(.appCaption)
                .foregroundStyle(theme.warning)
        }
        if let info = vm.lastInfo {
            Text(info)
                .font(.appCaption)
                .foregroundStyle(theme.success)
        }
        HStack {
            Text("\(vm.rules.count) rules")
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Button {
                Task { await vm.save() }
            } label: {
                Label(LumiPluginLocalization.string("Save", bundle: .module),
                      systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
