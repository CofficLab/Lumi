import LumiUI
import SwiftUI

/// App Store Connect 的工具栏标题。
///
/// 当前工作区通过 `ToolbarProviding` 控制可见类别，标题本身是纯视图，
/// 不依赖已移除的旧工作区事件。
struct AppStoreConnectToolbarTitleView: View {
    let title: String

    var body: some View {
        AppToolbarTitleLabel(title: title)
    }
}
