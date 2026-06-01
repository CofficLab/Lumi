import Foundation
import Combine
import SuperLogKit
import SwiftUI

protocol AppManagerServicing: Sendable {
    func scanInstalledApps(force: Bool) async -> [AppModel]
    func calculateAppSize(for app: AppModel) async -> Int64
    func scanRelatedFiles(for app: AppModel) async -> [RelatedFile]
    func deleteFiles(_ files: [RelatedFile]) async throws
    func saveCache() async
    func revealInFinder(_ app: AppModel)
    func openApp(_ app: AppModel)
    func getAppInfo(_ app: AppModel) -> String
}

extension AppService: AppManagerServicing {}

/// 应用管理器视图模型
@MainActor
class AppManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    private let appService: any AppManagerServicing

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
    private var activeScanID: UUID?
    private var relatedFilesTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(appService: any AppManagerServicing = AppService()) {
        self.appService = appService

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
            .sink { [weak self] apps in
                self?.filteredApps = apps
            }
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
            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)开始从缓存加载应用列表")
            }
        }
        let apps = await appService.scanInstalledApps(force: false)
        if !apps.isEmpty {
            installedApps = apps
            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)从缓存加载 \(apps.count) 个应用")
            }
        } else if Self.verbose {
            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)缓存为空，需要扫描")
            }
        }
    }

    /// 扫描应用
    /// - Parameter force: 是否强制重新扫描
    func scanApps(force: Bool = false) async {
        if AppManagerPlugin.verbose {
                    AppManagerPlugin.logger.info("\(self.t)开始扫描应用 (force: \(force))")
        }
        // Cancel previous task if any
        scanTask?.cancel()
        let scanID = UUID()
        activeScanID = scanID

        let task = Task {
            await self.performScan(force: force, scanID: scanID)
        }
        scanTask = task
        await task.value
    }

    private func performScan(force: Bool, scanID: UUID) async {
        isLoading = true
        defer {
            if activeScanID == scanID {
                isLoading = false
                activeScanID = nil
                scanTask = nil
            }
        }

        // 先扫描应用列表
        let apps = await appService.scanInstalledApps(force: force)
        guard !Task.isCancelled, activeScanID == scanID else { return }

        // 立即显示应用列表（不等待大小计算）
        installedApps = apps
        if Self.verbose {
            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)App list loaded: \(self.installedApps.count) apps")
            }
        }

        // 在后台逐个计算大小，不阻塞 UI
        for index in apps.indices {
            if Task.isCancelled || activeScanID != scanID { break }
            var sizedApp = apps[index]

            // 仅当大小为0（未缓存）时才计算
            if sizedApp.size == 0 {
                sizedApp.size = await appService.calculateAppSize(for: sizedApp)
                
                if Task.isCancelled || activeScanID != scanID { break }

                // 更新单个应用的大小（主线程）
                await MainActor.run {
                    // 确保索引仍然有效（防止在扫描期间卸载应用导致崩溃）
                    if activeScanID == scanID,
                       index < installedApps.count,
                       installedApps[index].id == sizedApp.id {
                        installedApps[index] = sizedApp
                    }
                }
            }
        }

        // 扫描结束后保存缓存
        if !Task.isCancelled, activeScanID == scanID {
            await appService.saveCache()
        }

        if AppManagerPlugin.verbose {
                    AppManagerPlugin.logger.info("\(self.t)扫描完成：\(self.installedApps.count) 个应用")
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
        if AppManagerPlugin.verbose {
                    AppManagerPlugin.logger.info("\(self.t)开始扫描关联文件：\(app.displayName)")
        }
        relatedFilesTask?.cancel()

        let appPath = app.bundleURL.path
        let appName = app.displayName
        isScanningFiles = true
        relatedFiles = []
        selectedFileIds = []

        relatedFilesTask = Task { [app, appService] in
            let files = await appService.scanRelatedFiles(for: app)
            guard !Task.isCancelled else { return }

            if AppManagerPlugin.verbose {
                            AppManagerPlugin.logger.info("\(self.t)关联文件扫描完成：\(app.displayName)，\(files.count) 个")
            }
            await MainActor.run {
                guard !Task.isCancelled, self.selectedApp?.bundleURL.path == appPath else {
                    if AppManagerPlugin.verbose {
                                            AppManagerPlugin.logger.info("\(self.t)忽略过期关联文件扫描结果：\(appName)")
                    }
                    return
                }

                self.relatedFiles = files
                // 默认全选
                self.selectedFileIds = Set(files.map { $0.id })
                self.isScanningFiles = false
                self.relatedFilesTask = nil
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
        if AppManagerPlugin.verbose {
                    AppManagerPlugin.logger.info("\(self.t)开始删除选中的 \(filesToDelete.count) 个文件")
        }
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
                        if AppManagerPlugin.verbose {
                                                    AppManagerPlugin.logger.info("\(self.t)应用已卸载：\(app.displayName)")
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
                    if AppManagerPlugin.verbose {
                                            AppManagerPlugin.logger.error("\(self.t)删除文件失败：\(error.localizedDescription)")
                    }
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
        clearRelatedFiles()
        selectedApp = nil
        showUninstallConfirmation = false
    }

    func clearRelatedFiles() {
        relatedFilesTask?.cancel()
        relatedFilesTask = nil
        relatedFiles = []
        selectedFileIds = []
        isScanningFiles = false
    }

    deinit {
        scanTask?.cancel()
        relatedFilesTask?.cancel()
    }
}
