import SwiftUI

/// 文件树的根层包裹。
struct ProjectTreeRootOverlay<Content: View>: View {
    let content: Content

    var body: some View {
        content
    }
}
