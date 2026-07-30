import LumiUI
import SwiftUI

/// 对话列表加载视图
struct ListLoadingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}