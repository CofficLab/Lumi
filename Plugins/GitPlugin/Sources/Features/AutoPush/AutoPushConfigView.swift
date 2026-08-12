import SwiftUI
import LumiUI
import LumiKernel

/// Auto Push 配置与监控面板。
public struct AutoPushConfigView: View {
    let project: any ProjectProviding
    @StateObject private var service = AutoPushService.shared
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(project: any ProjectProviding) {
        self.project = project
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.to.line")
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(service.config.enabled ? theme.success : theme.textTertiary)
                Text(LumiPluginLocalization.string("Auto Push", bundle: .module))
                    .font(.appTitle)
                if service.isRunning {
                    Text("· running")
                        .font(.appCaption)
                        .foregroundStyle(theme.success)
                }
                Spacer()
            }

            Form {
                Toggle(LumiPluginLocalization.string("Enable auto push", bundle: .module),
                       isOn: $service.config.enabled)
                Stepper(value: $service.config.intervalSeconds, in: 10...3600, step: 10) {
                    HStack {
                        Text(LumiPluginLocalization.string("Interval", bundle: .module))
                        Spacer()
                        Text("\(service.config.intervalSeconds)s")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $service.config.minUnpushedCommits, in: 0...50) {
                    HStack {
                        Text(LumiPluginLocalization.string("Min unpushed commits", bundle: .module))
                        Spacer()
                        Text("\(service.config.minUnpushedCommits)")
                            .foregroundStyle(.secondary)
                    }
                }
                TextField(LumiPluginLocalization.string("Remote name", bundle: .module),
                          text: $service.config.remote)
                Toggle(LumiPluginLocalization.string("Only push when working tree is clean", bundle: .module),
                       isOn: $service.config.requireCleanWorkingTree)
            }
            .formStyle(.grouped)

            HStack(spacing: 8) {
                if service.isRunning {
                    Button(role: .destructive) {
                        service.stop()
                    } label: {
                        Label(LumiPluginLocalization.string("Stop", bundle: .module),
                              systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        service.configure(projectPath: project.currentProject?.path ?? "")
                        service.start()
                    } label: {
                        Label(LumiPluginLocalization.string("Start", bundle: .module),
                              systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(project.currentProject == nil)
                }
                Button {
                    Task { await service.tick() }
                } label: {
                    Label(LumiPluginLocalization.string("Push now", bundle: .module),
                          systemImage: "arrow.up.circle")
                }
                .buttonStyle(.bordered)
            }

            if let err = service.lastError {
                Text(err)
                    .font(.appCaption)
                    .foregroundStyle(theme.warning)
            }
            if let info = service.lastInfo {
                Text(info)
                    .font(.appCaption)
                    .foregroundStyle(theme.success)
            }
            if let last = service.lastRunAt {
                Text("Last run: \(last, style: .relative) ago")
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            service.configure(projectPath: project.currentProject?.path ?? "")
        }
        .onChange(of: project.currentProject?.path ?? "") { _, newPath in
            service.stop()
            service.configure(projectPath: newPath)
            if service.config.enabled { service.start() }
        }
    }
}
