import LumiKernel
import LumiUI
import SwiftUI

/// 面板顶部内容视图
struct PanelHeaderView: View {
    private let layoutManager: WorkspaceProviding

    @LumiTheme private var theme

    init(layoutManager: WorkspaceProviding) {
        self.layoutManager = layoutManager
    }

    private var isVisible: Bool {
        layoutManager.layoutState.isPanelHeaderVisible
    }

    private var items: [PanelHeaderItem] {
        []
    }

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    item.makeView()
                        .id(item.id)
                }
            }
        }
    }
}
