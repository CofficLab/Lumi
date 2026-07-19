import SwiftUI
import SuperLogKit
import LumiUI
import LumiKernel
import XcodeKit

/// Xcode 项目状态栏视图
public struct XcodeProjectStatusBar: View, SuperLog {
    public nonisolated static let emoji = "🔨"

    @LumiTheme private var theme
    @ObservedObject private var viewModel: XcodeProjectStatusBarViewModel
    @ObservedObject private var buildRunManager: SwiftBuildRunManager

    public init(viewModel: XcodeProjectStatusBarViewModel? = nil) {
        let resolved = viewModel ?? EditorSwiftWindowScopeRegistry.activeStatusBarViewModel
        _viewModel = ObservedObject(wrappedValue: resolved)
        _buildRunManager = ObservedObject(wrappedValue: EditorSwiftWindowScopeRegistry.activeBuildRunManager)
    }

    public var body: some View {
        Group {
            if viewModel.showsBuildToolbar {
                toolbarContent
            }
        }
        .onAppear {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(self.t)onAppear，isXcodeProject=\(viewModel.isXcodeProject)")
                }
            }
        }
        .onChange(of: viewModel.isXcodeProject) { _, newValue in
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(self.t)isXcodeProject 变化: \(newValue)")
                }
            }
        }
    }

    private var toolbarContent: some View {
        HStack(spacing: 8) {
            if viewModel.isXcodeProject {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                    .help(LumiPluginLocalization.string("Xcode build context", bundle: .module))

                schemeMenu
                configurationMenu
                destinationChip
            } else if viewModel.isSwiftPackageProject {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)

                if let packageName = viewModel.spmPackageName {
                    Text(packageName)
                        .lineLimit(1)
                }
                if let target = viewModel.spmExecutableTarget {
                    Text(target)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftBuildRunButton(
                viewModel: viewModel,
                buildRunManager: EditorSwiftWindowScopeRegistry.activeBuildRunManager
            )

            if buildRunManager.isActive {
                Text(buildPhaseLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            if viewModel.isXcodeProject {
                statusDetailPopoverTrigger
            }
        }
        .padding(.horizontal, 4)
    }

    private var statusDetailPopoverTrigger: some View {
        StatusBarHoverContainer(
            detailView: XcodeProjectStatusDetailView(viewModel: viewModel),
            popoverWidth: 440,
            id: "lumi-xcode-project-status",
            chrome: .titleToolbar
        ) {
            buildContextIndicator
        }
    }

    // MARK: - Build Context 状态指示器

    private var buildContextIndicator: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 4) {
                if viewModel.showsActivityIndicator {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }

                if !viewModel.showsActivityIndicator {
                    Text(statusText(at: context.date))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .help(viewModel.semanticStatusDescription)
        }
    }

    static func titleToolbarSecondaryTextColor(theme: any LumiUITheme) -> Color {
        theme.textSecondary
    }

    static func titleToolbarPrimaryTextColor(theme: any LumiUITheme) -> Color {
        theme.textPrimary
    }

    @ViewBuilder
    private var schemeMenu: some View {
        if !viewModel.schemes.isEmpty {
            Menu {
                ForEach(viewModel.schemes, id: \.self) { scheme in
                    Button(action: {
                        viewModel.setActiveScheme(scheme)
                    }) {
                        HStack {
                            Text(scheme)
                            if scheme == viewModel.activeScheme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(viewModel.activeScheme ?? LumiPluginLocalization.string("Scheme", bundle: .module))
                    .lineLimit(1)
            }
        } else if viewModel.isXcodeProject {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(schemePlaceholderText(at: context.date))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func schemePlaceholderText(at date: Date) -> String {
        if let activeScheme = viewModel.activeScheme {
            return activeScheme
        }
        if viewModel.isResolvingBuildContext {
            return viewModel.semanticStatusText(now: date)
        }
        return viewModel.schemePlaceholderText
    }

    @ViewBuilder
    private var configurationMenu: some View {
        if !viewModel.configurations.isEmpty {
            Menu {
                ForEach(viewModel.configurations, id: \.self) { configuration in
                    Button(action: {
                        viewModel.setActiveConfiguration(configuration)
                    }) {
                        HStack {
                            Text(configuration)
                            if configuration == viewModel.activeConfiguration {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(viewModel.activeConfiguration ?? LumiPluginLocalization.string("Config", bundle: .module))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var destinationChip: some View {
        if let destination = viewModel.activeDestination, !destination.isEmpty {
            Text(destination)
                .lineLimit(1)
                .help(LumiPluginLocalization.string("Target platform for current editor semantic context", bundle: .module))
        }
    }

    private var statusColor: Color {
        viewModel.semanticStatusColor
    }

    private func statusText(at date: Date) -> String {
        viewModel.semanticStatusText(now: date)
    }

    private var buildPhaseLabel: String {
        switch buildRunManager.phase {
        case .preflighting:
            return LumiPluginLocalization.string("Preparing…", bundle: .module)
        case .building:
            return LumiPluginLocalization.string("Building…", bundle: .module)
        case .launching:
            return LumiPluginLocalization.string("Launching…", bundle: .module)
        default:
            return LumiPluginLocalization.string("Running…", bundle: .module)
        }
    }
}
#Preview {
    XcodeProjectStatusBar()
        .padding()
}
