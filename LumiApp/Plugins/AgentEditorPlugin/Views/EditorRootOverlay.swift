import MagicKit
import SwiftUI

/// Editor 根视图覆盖层
///
/// 包裹 RootView，确保文件选择监听始终生效。
struct EditorRootOverlay<Content: View>: View {
    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
