import Foundation
import OSLog

/// 应用管理器视图模型
@MainActor
class AppManagerViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "AppManagerViewModel")
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

    /// 扫描应用
    func scanApps() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 先扫描应用列表
            let apps = await appService.scanInstalledApps()

            // 立即显示应用列表（不等待大小计算）
            installedApps = apps
            logger.info("应用列表加载完成，共 \(self.installedApps.count) 个应用")

            // 在后台逐个计算大小，不阻塞 UI
            for index in apps.indices {
                var sizedApp = apps[index]
                sizedApp.size = await appService.calculateAppSize(for: sizedApp)

                // 更新单个应用的大小（主线程）
                await MainActor.run {
                    installedApps[index] = sizedApp
                }
            }

            logger.info("应用扫描完成，共 \(self.installedApps.count) 个应用")
        } catch {
            logger.error("扫描应用失败: \(error.localizedDescription)")
            errorMessage = "扫描失败: \(error.localizedDescription)"
        }
    }

    /// 刷新应用列表
    func refresh() {
        Task {
            await scanApps()
        }
    }

    /// 卸载应用
    func uninstallApp(_ app: AppModel) async {
        do {
            try await appService.uninstallApp(app)

            // 从列表中移除
            installedApps.removeAll { $0.bundleURL.path == app.bundleURL.path }

            logger.info("卸载成功: \(app.displayName)")
            errorMessage = nil
        } catch {
            logger.error("卸载失败: \(error.localizedDescription)")
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
