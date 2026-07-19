import LumiKernel
import LumiUI
import SwiftUI

struct SwiftBuildRunButton: View {
    @ObservedObject var viewModel: XcodeProjectStatusBarViewModel
    @ObservedObject var buildRunManager: SwiftBuildRunManager

    var body: some View {
        Group {
            if buildRunManager.isActive {
                Button {
                    buildRunManager.cancel()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Stop Build", bundle: .module))
            } else {
                AppIconButton(
                    systemImage: buildRunManager.phase == .failed ? "exclamationmark.triangle.fill" : "play.fill",
                    label: nil,
                    tint: buildRunManager.phase == .failed ? .orange : .green,
                    size: .compact,
                    isActive: true
                ) {
                    triggerRun()
                }
                .help(runHelpText)
            }
        }
        .task(id: preflightRefreshKey) {
            await refreshPreflight()
        }
    }

    private func triggerRun() {
        buildRunManager.run(
            provider: viewModel.buildContextProvider,
            projectPath: viewModel.activeProjectPath,
            currentFileURL: nil,
            fallbackScheme: viewModel.activeScheme,
            fallbackConfiguration: viewModel.activeConfiguration,
            fallbackDestinationQuery: viewModel.buildContextProvider?.activeDestination?.destinationQuery
        )
    }

    private func refreshPreflight() async {
        await buildRunManager.refreshPreflight(
            provider: viewModel.buildContextProvider,
            projectPath: viewModel.activeProjectPath,
            currentFileURL: nil,
            fallbackScheme: viewModel.activeScheme,
            fallbackConfiguration: viewModel.activeConfiguration,
            fallbackDestinationQuery: viewModel.buildContextProvider?.activeDestination?.destinationQuery
        )
    }

    private var preflightRefreshKey: String {
        [
            viewModel.activeProjectPath ?? "",
            viewModel.activeScheme ?? "",
            viewModel.activeConfiguration ?? "",
            viewModel.activeDestination ?? "",
            viewModel.isSwiftPackageProject ? "spm" : "xcode",
            viewModel.spmExecutableTarget ?? "",
        ].joined(separator: "|")
    }

    private var runHelpText: String {
        if let reason = buildRunManager.runDisabledReason {
            return reason
        }
        if buildRunManager.phase == .succeeded {
            return LumiPluginLocalization.string("Run again", bundle: .module)
        }
        return LumiPluginLocalization.string("Build and Run", bundle: .module)
    }
}
