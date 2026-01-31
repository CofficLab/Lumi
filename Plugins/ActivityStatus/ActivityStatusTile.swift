import SwiftUI

/// 状态栏活动状态瓦片，显示当前应用状态和活动信息
struct ActivityStatusTile: View {
    @EnvironmentObject var appProvider: AppProvider

    /// 当前显示的状态文本
    @State private var currentStatus: String? = nil

    var body: some View {
        let statusToShow = currentStatus ?? appProvider.activityStatus

        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.caption)
            Text(statusToShow ?? "")
                .font(.footnote)
                .foregroundColor(.primary)
        }
        .opacity(statusToShow?.isEmpty == false ? 1.0 : 0.0)
        .onApplicationDidFinishLaunching(perform: handleAppDidLaunch)
        .onApplicationWillTerminate(perform: handleAppWillTerminate)
        .onApplicationDidBecomeActive(perform: handleAppDidBecomeActive)
        .onApplicationDidResignActive(perform: handleAppDidResignActive)
    }

    /// 根据当前状态返回合适的图标
    private var statusIcon: String {
        if currentStatus != nil {
            // 应用状态使用应用图标
            return "app.badge"
        } else {
            // 活动状态使用旋转图标
            return "arrow.triangle.2.circlepath"
        }
    }

    /// 更新应用状态的方法
    /// - Parameter status: 新的状态文本，为nil则清除状态
    private func updateAppStatus(_ status: String?) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStatus = status
        }
    }

    // MARK: - Event Handlers

    /// 处理应用启动完成事件
    private func handleAppDidLaunch() {
        updateAppStatus("应用已就绪")
        // 3秒后清除状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            updateAppStatus(nil)
        }
    }

    /// 处理应用即将终止事件
    private func handleAppWillTerminate() {
        updateAppStatus("正在关闭应用...")
    }

    /// 处理应用变为活跃状态事件
    private func handleAppDidBecomeActive() {
        updateAppStatus("应用已激活")
        // 2秒后清除状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            updateAppStatus(nil)
        }
    }

    /// 处理应用变为非活跃状态事件
    private func handleAppDidResignActive() {
        updateAppStatus("应用已进入后台")
        // 1秒后清除状态，避免状态持续显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            updateAppStatus(nil)
        }
    }
}

// MARK: - Preview

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

#Preview("With Activity Status") {
    ActivityStatusTile()
        .onAppear {
            // Preview中无法直接注入有状态的对象
            // 此Preview仅展示布局，实际使用时会通过AppProvider注入
        }
}
