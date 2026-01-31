import SwiftUI

/// 工具栏操作按钮视图
struct ToolbarActionButton: View {
    /// 控制alert显示状态
    @State private var showAlert = false

    var body: some View {
        Button(action: {
            // 点击时显示alert
            showAlert = true
        }) {
            Image(systemName: ToolbarButtonPlugin.iconName)
                .foregroundColor(.blue)
        }
        .help(ToolbarButtonPlugin.displayName)
        .alert(ToolbarButtonPlugin.displayName, isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您点击了\(ToolbarButtonPlugin.displayName)！")
        }
    }
}

// MARK: - Preview

#Preview("Toolbar Button") {
    HStack {
        Spacer()
        ToolbarActionButton()
    }
    .padding()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
