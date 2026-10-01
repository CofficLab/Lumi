import SwiftUI

/// 内容区占位视图（有活跃容器但未注入内容时）。
@MainActor
struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("Root View", bundle: .module))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
