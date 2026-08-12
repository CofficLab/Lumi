import LumiUI
import SwiftUI

/// 数据库工作区根视图：在主面板外层套一个可收起的右侧 Inspector。
///
/// 宿主 App 没有原生的 inspector 区域，这里用 macOS 14+ 的 `.inspector` 修饰符
/// 在 viewContainer 自己的 PanelBody 内部切出右侧面板，既不污染宿主布局，
/// 又能与 ``DatabaseViewModel`` 共享同一份状态。
///
/// Inspector 当前的内容是占位（``DatabaseInspectorView``），后续 Phase 会逐步填入：
/// - Phase 2/3：选中表的结构详情与行详情
/// - Phase 4：EXPLAIN 可视化
/// - Phase 6：ER 关系图
public struct DatabaseWorkspaceView: View {
    @ObservedObject var viewModel: DatabaseViewModel

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        MainView(viewModel: viewModel)
            .inspector(isPresented: $viewModel.inspectorVisible) {
                DatabaseInspectorView(viewModel: viewModel)
                    .inspectorColumnWidth(min: 240, ideal: 320, max: 560)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.toggleInspector()
                } label: {
                    Image(systemName: viewModel.inspectorVisible ? "sidebar.trailing.collapse" : "sidebar.trailing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Toggle Inspector", bundle: .module))
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
    }
}
