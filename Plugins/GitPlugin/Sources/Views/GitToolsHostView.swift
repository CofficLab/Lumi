import SwiftUI
import LumiUI
import LumiKernel

/// 整合 6 个新增 Git 工具的宿主视图（Stash / .gitignore / LFS / Submodule / Conflict / AutoPush）。
///
/// 渲染为 `AppSegmentedControl` 顶部切换 + 下方对应面板。
public struct GitToolsHostView: View {
    let project: any ProjectProviding
    @State private var selectedTab: ToolTab = .stash

    public init(project: any ProjectProviding) {
        self.project = project
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            segmented
            Divider()
            ScrollView {
                currentPanel
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var segmented: some View {
        AppSegmentedControl(
            ToolTab.allCases.map(\.title),
            selection: Binding(
                get: { ToolTab.allCases.firstIndex(of: selectedTab) ?? 0 },
                set: { selectedTab = ToolTab.allCases[$0] }
            )
        )
        .padding(12)
    }

    @ViewBuilder
    private var currentPanel: some View {
        switch selectedTab {
        case .stash:      GitStashPanelView(project: project)
        case .gitignore:  GitIgnorePanelView(project: project)
        case .lfs:        GitLFSPanelView(project: project)
        case .submodule:  GitSubmodulePanelView(project: project)
        case .conflict:   GitConflictPanelView(project: project)
        case .autopush:   AutoPushConfigView(project: project)
        }
    }
}

public enum ToolTab: String, CaseIterable, Identifiable {
    case stash
    case gitignore
    case lfs
    case submodule
    case conflict
    case autopush

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .stash:     return "Stash"
        case .gitignore: return ".gitignore"
        case .lfs:       return "LFS"
        case .submodule: return "Submodule"
        case .conflict:  return "Conflicts"
        case .autopush:  return "Auto Push"
        }
    }
}
