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

    var body: some View {
        if layoutManager.isPanelHeaderVisible {
            VStack(spacing: 0) {
                ForEach(self.layoutManager.allPanelHeaderItems) { item in
                    item.makeView()
                        .id(item.id)
                }
            }
        }
    }
}
