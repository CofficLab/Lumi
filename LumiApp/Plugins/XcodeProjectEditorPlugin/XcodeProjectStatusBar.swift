import Combine
import SwiftUI

/// Xcode 项目状态栏视图
/// 对应 Phase 8: scheme / destination / configuration 状态栏
struct XcodeProjectStatusBar: View {
    
    @StateObject private var viewModel = XcodeProjectStatusBarViewModel()
    @State private var showSchemePicker = false
    
    var body: some View {
        Group {
            if viewModel.isXcodeProject {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)

                    schemeMenu
                    configurationMenu
                    destinationChip

                    buildContextIndicator
                }
                .padding(.horizontal, 4)
                .frame(width: 400, alignment: .leading)
            }
        }
    }
    
    // MARK: - Build Context 状态指示器
    
    private var buildContextIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .help(viewModel.buildContextStatusDescription)
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
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text(viewModel.activeScheme ?? "Scheme")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
            }
        }
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
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 8))
                    Text(viewModel.activeConfiguration ?? "Config")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
            }
        }
    }

    @ViewBuilder
    private var destinationChip: some View {
        if let destination = viewModel.activeDestination, !destination.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "macwindow")
                    .font(.system(size: 8))
                Text(destination)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .cornerRadius(4)
            .help("当前编辑器语义上下文的目标平台")
        }
    }

    private var statusColor: Color {
        switch viewModel.buildContextStatus {
        case .unknown: return .gray
        case .resolving: return .yellow
        case .available: return .green
        case .unavailable: return .red
        case .needsResync: return .orange
        }
    }
    
    private var statusText: String {
        switch viewModel.buildContextStatus {
        case .unknown: return "未检测"
        case .resolving: return "解析中..."
        case .available: return "就绪"
        case .unavailable: return "错误"
        case .needsResync: return "需同步"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class XcodeProjectStatusBarViewModel: ObservableObject {
    @Published var isXcodeProject = false
    @Published var activeScheme: String?
    @Published var schemes: [String] = []
    @Published var activeConfiguration: String?
    @Published var configurations: [String] = []
    @Published var activeDestination: String?
    @Published var buildContextStatus: XcodeBuildContextProvider.BuildContextStatus = .unknown
    @Published var buildContextStatusDescription = "未初始化"
    private var notificationCancellable: AnyCancellable?
    
    private var provider: XcodeBuildContextProvider?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setup()
    }
    
    private func setup() {
        let bridge = XcodeProjectContextBridge.shared
        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.cachedActiveScheme
        activeConfiguration = bridge.activeConfiguration
        activeDestination = bridge.activeDestination
        buildContextStatusDescription = bridge.buildContextStatusDescription
        
        guard let provider = bridge.buildContextProvider else { return }
        self.provider = provider
        schemes = provider.currentWorkspace?.schemes.map(\.name) ?? []
        configurations = Array(Set(provider.currentWorkspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
        activeConfiguration = provider.activeConfiguration
        buildContextStatus = provider.buildContextStatus
        
        // 订阅 provider 的状态变化
        provider.$buildContextStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.buildContextStatus = status
                self?.buildContextStatusDescription = status.displayDescription
            }
            .store(in: &cancellables)
        
        provider.$currentWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] workspace in
                guard let self else { return }
                self.isXcodeProject = workspace != nil
                self.schemes = workspace?.schemes.map(\.name) ?? []
                self.configurations = Array(Set(workspace?.projects.flatMap(\.buildConfigurations).map(\.name) ?? [])).sorted()
                self.activeScheme = workspace?.activeScheme?.name
                self.activeConfiguration = workspace?.activeScheme?.activeConfiguration
            }
            .store(in: &cancellables)

        provider.$activeScheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scheme in
                self?.activeScheme = scheme?.name
                self?.activeConfiguration = scheme?.activeConfiguration
            }
            .store(in: &cancellables)

        provider.$activeConfiguration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                self?.activeConfiguration = configuration
            }
            .store(in: &cancellables)

        provider.$activeDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                self?.activeDestination = destination?.name
            }
            .store(in: &cancellables)

        notificationCancellable = NotificationCenter.default
            .publisher(for: .lumiEditorXcodeContextDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.activeDestination = XcodeProjectContextBridge.shared.activeDestination
            }
    }
    
    func setActiveScheme(_ schemeName: String) {
        guard let provider, let scheme = provider.currentWorkspace?.schemes.first(where: { $0.name == schemeName }) else { return }
        Task {
            await provider.setActiveScheme(scheme)
        }
    }

    func setActiveConfiguration(_ configurationName: String) {
        guard let provider else { return }
        Task {
            await provider.setActiveConfiguration(configurationName)
        }
    }
}

// MARK: - 文件归属提示视图

/// 文件未绑定到任何 Target 的提示
/// 对应 Phase 8: "当前文件未绑定有效 target" 提示
struct XcodeFileNotInTargetWarning: View {
    let fileName: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("文件未在项目中注册")
                    .font(.headline)
            }
            
            Text("\"\(fileName)\" 未绑定到任何编译 target，跨文件语义导航可能不可用。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("我知道了", action: onDismiss)
                    .buttonStyle(.bordered)
                
                Button("在 Xcode 中打开") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        XcodeProjectStatusBar()
            .padding()
        
        Divider()
        
        XcodeFileNotInTargetWarning(fileName: "MyFile.swift") { }
            .padding()
    }
}
