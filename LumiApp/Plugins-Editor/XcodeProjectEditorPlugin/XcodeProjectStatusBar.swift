import SwiftUI

/// Xcode 项目状态栏视图
/// 对应 Phase 8: scheme / destination / configuration 状态栏
struct XcodeProjectStatusBar: View {
    
    @StateObject private var viewModel = XcodeProjectStatusBarViewModel()
    @State private var showSchemePicker = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Xcode 项目标识
            if viewModel.isXcodeProject {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
            }
            
            // Scheme 选择器
            if viewModel.isXcodeProject, !viewModel.schemes.isEmpty {
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
            
            // Build Context 状态指示器
            if viewModel.isXcodeProject {
                buildContextIndicator
            }
        }
        .padding(.horizontal, 4)
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
    @Published var buildContextStatus: XcodeBuildContextProvider.BuildContextStatus = .unknown
    @Published var buildContextStatusDescription = "未初始化"
    
    private var provider: XcodeBuildContextProvider?
    
    init() {
        setup()
    }
    
    private func setup() {
        let bridge = XcodeProjectContextBridge.shared
        isXcodeProject = bridge.isXcodeProject
        activeScheme = bridge.cachedActiveScheme
        buildContextStatusDescription = bridge.buildContextStatusDescription
        
        if let provider = bridge.buildContextProvider {
            self.provider = provider
            schemes = provider.currentWorkspace?.schemes.map(\.name) ?? []
            buildContextStatus = provider.buildContextStatus
        }
    }
    
    func setActiveScheme(_ schemeName: String) {
        guard let provider, let scheme = provider.currentWorkspace?.schemes.first(where: { $0.name == schemeName }) else { return }
        Task {
            await provider.setActiveScheme(scheme)
            await MainActor.run {
                activeScheme = schemeName
                buildContextStatus = provider.buildContextStatus
                buildContextStatusDescription = provider.buildContextStatus.displayDescription
            }
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
