import Foundation
import Combine
import MagicKit
import SwiftUI

/// 应用管理器视图模型
@MainActor
class AppManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    private let appService = AppService()

    @Published var installedApps: [AppModel] = []
    @Published var filteredApps: [AppModel] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedApp: AppModel? = nil
    @Published var relatedFiles: [RelatedFile] = []
    @Published var selectedFileIds: Set<UUID> = []
    @Published var isScanningFiles = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var showUninstallConfirmation = false
    
    private var scanTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Setup search debounce
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .combineLatest($installedApps)
            .map { (text, apps) -> [AppModel] in
                if text.isEmpty { return apps }
                return apps.filter { app in
                    app.displayName.localizedCaseInsensitiveContains(text) ||
                    (app.bundleIdentifier?.localizedCaseInsensitiveContains(text) ?? false)
                }
            }
            .assign(to: \.filteredApps, on: self)
            .store(in: &cancellables)
    }
    var totalSelectedSize: Int64 {
        relatedFiles.filter { selectedFileIds.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    /// 总大小
    var totalSize: Int64 {
        installedApps.reduce(0) { $0 + $1.size }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var formattedTotalSize: String {
        Self.byteFormatter.string(fromByteCount: totalSize)
    }

    /// 从缓存加载应用列表（首次加载时调用）
    func loadFromCache() async {
        if Self.verbose {
            AppManagerPlugin.logger.info("\(self.t)开始从缓存加载应用列表")
        }
        let apps = await appService.scanInstalledApps(force: false)
        if !apps.isEmpty {
            installedApps = apps
            AppManagerPlugin.logger.info("\(self.t)从缓存加载 \(apps.count) 个应用")
        } else if Self.verbose {
            AppManagerPlugin.logger.info("\(self.t)缓存为空，需要扫描")
        }
    }

    /// 扫描应用
    /// - Parameter force: 是否强制重新扫描
    func scanApps(force: Bool = false) async {
        AppManagerPlugin.logger.info("\(self.t)开始扫描应用 (force: \(force))")
        // Cancel previous task if any
        scanTask?.cancel()
        
        // Wrap in TaskService for global tracking
        scanTask = Task {
            try? await TaskService.shared.run(title: "Scanning app list", priority: .userInitiated) { progressCallback in
                await self.performScan(force: force, progressCallback: progressCallback)
            }
        }
        await scanTask?.value
    }

    private func performScan(force: Bool, progressCallback: @escaping @Sendable (Double) -> Void) async {
        isLoading = true
        defer { isLoading = false }
        
        progressCallback(0.1)

        // 先扫描应用列表
        let apps = await appService.scanInstalledApps(force: force)
        if Task.isCancelled { return }
        
        progressCallback(0.3)

        // 立即显示应用列表（不等待大小计算）
        installedApps = apps
        if Self.verbose {
            AppManagerPlugin.logger.info("\(self.t)App list loaded: \(self.installedApps.count) apps")
        }

        // 在后台逐个计算大小，不阻塞 UI
        let total = Double(apps.count)
        for index in apps.indices {
            if Task.isCancelled { break }
            var sizedApp = apps[index]

            // 仅当大小为0（未缓存）时才计算
            if sizedApp.size == 0 {
                sizedApp.size = await appService.calculateAppSize(for: sizedApp)
                
                if Task.isCancelled { break }

                // 更新单个应用的大小（主线程）
                await MainActor.run {
                    // 确保索引仍然有效（防止在扫描期间卸载应用导致崩溃）
                    if index < installedApps.count && installedApps[index].id == sizedApp.id {
                        installedApps[index] = sizedApp
                    }
                }
            }
            // Update progress (from 0.3 to 1.0)
            let currentProgress = 0.3 + (0.7 * Double(index + 1) / total)
            progressCallback(currentProgress)
        }
        
        progressCallback(1.0)

        // 扫描结束后保存缓存
        if !Task.isCancelled {
            await appService.saveCache()
        }

        AppManagerPlugin.logger.info("\(self.t)扫描完成：\(self.installedApps.count) 个应用")
    }

    /// 刷新应用列表
    func refresh() {
        Task {
            await scanApps(force: true)
        }
    }

    /// 扫描关联文件
    func scanRelatedFiles(for app: AppModel) {
        AppManagerPlugin.logger.info("\(self.t)开始扫描关联文件：\(app.displayName)")
        Task {
            await MainActor.run {
                isScanningFiles = true
            }
            let files = await appService.scanRelatedFiles(for: app)
            AppManagerPlugin.logger.info("\(self.t)关联文件扫描完成：\(app.displayName)，\(files.count) 个")
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
        let filesToDelete = relatedFiles.filter { selectedFileIds.contains($0.id) }
        AppManagerPlugin.logger.info("\(self.t)开始删除选中的 \(filesToDelete.count) 个文件")
        isDeleting = true

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
                        AppManagerPlugin.logger.info("\(self.t)应用已卸载：\(app.displayName)")
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
                    AppManagerPlugin.logger.error("\(self.t)删除文件失败：\(error.localizedDescription)")
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
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
