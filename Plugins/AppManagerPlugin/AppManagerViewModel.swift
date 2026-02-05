import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 应用管理器视图模型
@MainActor
class AppManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "📋"
    static let verbose = true

    private let appService = AppService()

    @Published var installedApps: [AppModel] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedApp: AppModel? {
        didSet {
            guard selectedApp != oldValue else { return }

            // 使用 Task 异步执行，避免在视图更新周期内修改其他 @Published 属性
            Task {
                if let app = selectedApp {
                    scanRelatedFiles(for: app)
                } else {
                    relatedFiles = []
                    selectedFileIds = []
                }
            }
        }
    }

    @Published var relatedFiles: [RelatedFile] = []
    @Published var selectedFileIds: Set<UUID> = []
    @Published var isScanningFiles = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var showUninstallConfirmation = false

    var totalSelectedSize: Int64 {
        relatedFiles.filter { selectedFileIds.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

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
    }

    /// 刷新应用列表
    func refresh() {
        Task {
            await scanApps(force: true)
        }
    }

    /// 扫描关联文件
    func scanRelatedFiles(for app: AppModel) {
        Task {
            await MainActor.run {
                isScanningFiles = true
            }
            let files = await appService.scanRelatedFiles(for: app)
            await MainActor.run {
                self.relatedFiles = files
                // 默认全选
                self.selectedFileIds = Set(files.map { $0.id })
                self.isScanningFiles = false
            }
        }
    }

    func toggleFileSelection(_ id: UUID) {
        if selectedFileIds.contains(id) {
            selectedFileIds.remove(id)
        } else {
            selectedFileIds.insert(id)
        }
    }

    /// 删除选中的文件
    func deleteSelectedFiles() {
        guard !selectedFileIds.isEmpty else { return }
        isDeleting = true

        let filesToDelete = relatedFiles.filter { selectedFileIds.contains($0.id) }

        Task {
            do {
                try await appService.deleteFiles(filesToDelete)

                await MainActor.run {
                    self.isDeleting = false
                    self.showUninstallConfirmation = false

                    // 检查主 App 是否被删除
                    if let app = self.selectedApp, self.selectedFileIds.contains(where: { id in
                        if let file = self.relatedFiles.first(where: { $0.id == id }) {
                            return file.type == .app
                        }
                        return false
                    }) {
                        // 如果删除了 App 本体，则从列表中移除 App
                        self.installedApps.removeAll { $0.bundleURL.path == app.bundleURL.path }
                        self.selectedApp = nil
                        self.relatedFiles = []

                        if Self.verbose {
                            os_log("\(self.t)App uninstalled: \(app.displayName)")
                        }
                    } else {
                        // 仅移除了部分文件，重新扫描以刷新状态（或者手动从 relatedFiles 移除）
                        if let app = self.selectedApp {
                            self.scanRelatedFiles(for: app)
                        }
                    }

                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.isDeleting = false
                    os_log(.error, "\(self.t)Uninstall failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
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
