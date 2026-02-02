import Foundation
import MagicKit
import SwiftUI
import OSLog

/// 应用管理器视图模型
@MainActor
class AppManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "📋"
    static let verbose = true

    private let appService = AppService()

    @Published var installedApps: [AppModel] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedApp: AppModel?
    @Published var errorMessage: String?
    @Published var showUninstallConfirmation = false

    /// 过滤后的应用列表
    var filteredApps: [AppModel] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter { app in
            app.displayName.localizedCaseInsensitiveContains(searchText) ||
                (app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    /// 总大小
    var totalSize: Int64 {
        installedApps.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// 从缓存加载应用列表（首次加载时调用）
    func loadFromCache() async {
        let apps = await appService.scanInstalledApps(force: false)
        if !apps.isEmpty {
            installedApps = apps
            if Self.verbose {
                os_log("\(self.t)从缓存加载 \(apps.count) 个应用")
            }
        }
    }

    /// 扫描应用
    /// - Parameter force: 是否强制重新扫描
    func scanApps(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 先扫描应用列表
            let apps = await appService.scanInstalledApps(force: force)

            // 立即显示应用列表（不等待大小计算）
            installedApps = apps
            if Self.verbose {
                os_log("\(self.t)App list loaded: \(self.installedApps.count) apps")
            }

            // 在后台逐个计算大小，不阻塞 UI
            for index in apps.indices {
                var sizedApp = apps[index]

                // 仅当大小为0（未缓存）时才计算
                if sizedApp.size == 0 {
                    sizedApp.size = await appService.calculateAppSize(for: sizedApp)

                    // 更新单个应用的大小（主线程）
                    await MainActor.run {
                        // 确保索引仍然有效（防止在扫描期间卸载应用导致崩溃）
                        if index < installedApps.count && installedApps[index].id == sizedApp.id {
                            installedApps[index] = sizedApp
                        }
                    }
                }
            }

            // 扫描结束后保存缓存
            appService.saveCache()

            if Self.verbose {
                os_log("\(self.t)Scan complete: \(self.installedApps.count) apps")
            }
        } catch {
            os_log(.error, "\(self.t)Scan failed: \(error.localizedDescription)")
            errorMessage = "扫描失败: \(error.localizedDescription)"
        }
    }

    /// 刷新应用列表
    func refresh() {
        Task {
            await scanApps(force: true)
        }
    }

    /// 卸载应用
    func uninstallApp(_ app: AppModel) async {
        do {
            try await appService.uninstallApp(app)

            // 从列表中移除
            installedApps.removeAll { $0.bundleURL.path == app.bundleURL.path }

            if Self.verbose {
                os_log("\(self.t)Uninstall successful: \(app.displayName)")
            }
            errorMessage = nil
        } catch {
            os_log(.error, "\(self.t)Uninstall failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// 在 Finder 中显示
    func revealInFinder(_ app: AppModel) {
        appService.revealInFinder(app)
    }

    /// 打开应用
    func openApp(_ app: AppModel) {
        appService.openApp(app)
    }

    /// 获取应用信息
    func getAppInfo(_ app: AppModel) -> String {
        appService.getAppInfo(app)
    }

    /// 取消选择
    func cancelSelection() {
        selectedApp = nil
        showUninstallConfirmation = false
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
