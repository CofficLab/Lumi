import SwiftUI

/// 空白占位视图。
///
/// 当没有加载用户 dylib 时，子进程显示此空白视图而非 demo 内容。
/// 正式上线后不再需要演示动画。
struct PreviewPlaceholderView: View {
    var body: some View {
        Color.clear
    }
}
