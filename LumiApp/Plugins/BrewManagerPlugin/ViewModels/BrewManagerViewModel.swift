import Foundation
import Combine
import SwiftUI
import MagicKit

@MainActor
class BrewManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🍺"
    nonisolated static let verbose: Bool = true
    @Published var installedPackages: [BrewPackage] = []
    @Published var outdatedPackages: [BrewPackage] = []
    @Published var searchResults: [BrewPackage] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isBrewInstalled: Bool = false
    
    // 搜索防抖
    private var searchCancellable: AnyCancellable?
    private let service = BrewService.shared
    
    init() {
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t) 初始化 BrewManagerViewModel")
        }
        checkEnvironment()
    }
    
    func checkEnvironment() {
        Task {
            if Self.verbose {
                BrewManagerPlugin.logger.info("\(self.t) 检查 Homebrew 环境")
            }
            isBrewInstalled = await service.checkInstalled()
            if isBrewInstalled {
                if Self.verbose {
                    BrewManagerPlugin.logger.info("\(self.t) Homebrew 已安装，开始刷新数据")
                }
                await refresh()
            } else {
                if Self.verbose {
                    BrewManagerPlugin.logger.error("\(self.t) ❌ Homebrew not detected")
                }
                errorMessage = String(localized: "Homebrew not detected, please install Homebrew first.", table: "BrewManager")
            }
        }
    }
    
    func refresh() async {
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t)🔄 Starting to refresh package list")
        }
        isLoading = true
        errorMessage = nil
        
        do {
            async let installed = service.listInstalled()
            async let outdated = service.getOutdated()
            
            let (installedList, outdatedList) = try await (installed, outdated)
            
            if Self.verbose {
                BrewManagerPlugin.logger.info("\(self.t) ✅ Refresh complete: \(installedList.count) installed, \(outdatedList.count) outdated")
            }
            
            self.installedPackages = installedList
            self.outdatedPackages = outdatedList
        } catch {
            if Self.verbose {
                BrewManagerPlugin.logger.error("\(self.t) ❌ Refresh failed: \(error.localizedDescription)")
            }
            self.errorMessage = String(localized: "Refresh failed: \(error.localizedDescription)", table: "BrewManager")
        }
        
        isLoading = false
    }
    
    func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t) 🔍 触发搜索: \(self.searchText)")
        }
        isLoading = true
        searchCancellable?.cancel()
        
        searchCancellable = Task {
            do {
                // 延迟 0.5s 防抖
                try await Task.sleep(nanoseconds: 500_000_000)
                
                if Self.verbose {
                    BrewManagerPlugin.logger.info("\(self.t) 执行搜索 API 调用: \(self.searchText)")
                }
                let results = try await service.search(query: searchText)
                
                if !Task.isCancelled {
                    if Self.verbose {
                        BrewManagerPlugin.logger.info("\(self.t) ✅ 搜索完成: 找到 \(results.count) 个结果")
                    }
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    if Self.verbose {
                        BrewManagerPlugin.logger.error("\(self.t) ❌ 搜索失败: \(error.localizedDescription)")
                    }
                    self.errorMessage = String(localized: "Search failed: \(error.localizedDescription)", table: "BrewManager")
                    self.isLoading = false
                }
            }
        }.asAnyCancellable()
    }
    
    func install(package: BrewPackage) async {
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t) ⬇️ 开始安装: \(package.name)")
        }
        isLoading = true
        do {
            try await service.install(name: package.name, isCask: package.isCask)
            if Self.verbose {
                BrewManagerPlugin.logger.info("\(self.t) ✅ 安装成功: \(package.name)")
            }
            await refresh()
        } catch {
            if Self.verbose {
                BrewManagerPlugin.logger.error("\(self.t) ❌ 安装失败: \(error.localizedDescription)")
            }
            errorMessage = String(localized: "Installation failed: \(error.localizedDescription)", table: "BrewManager")
        }
        isLoading = false
    }
    
    func uninstall(package: BrewPackage) async {
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t) 🗑️ 开始卸载: \(package.name)")
        }
        isLoading = true
        do {
            try await service.uninstall(name: package.name, isCask: package.isCask)
            if Self.verbose {
                BrewManagerPlugin.logger.info("\(self.t) ✅ 卸载成功: \(package.name)")
            }
            await refresh()
        } catch {
            if Self.verbose {
                BrewManagerPlugin.logger.error("\(self.t) ❌ 卸载失败: \(error.localizedDescription)")
            }
            errorMessage = String(localized: "Uninstallation failed: \(error.localizedDescription)", table: "BrewManager")
        }
        isLoading = false
    }
    
    func upgrade(package: BrewPackage) async {
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t) ⬆️ 开始更新: \(package.name)")
        }
        isLoading = true
        do {
            try await service.upgrade(name: package.name, isCask: package.isCask)
            if Self.verbose {
                BrewManagerPlugin.logger.info("\(self.t) ✅ 更新成功: \(package.name)")
            }
            await refresh()
        } catch {
            if Self.verbose {
                BrewManagerPlugin.logger.error("\(self.t) ❌ 更新失败: \(error.localizedDescription)")
            }
            errorMessage = String(localized: "Update failed: \(error.localizedDescription)", table: "BrewManager")
        }
        isLoading = false
    }
    
    func upgradeAll() async {
        if Self.verbose {
            BrewManagerPlugin.logger.info("\(self.t) 🚀 开始全部更新 (\(self.outdatedPackages.count) 个包)")
        }
        isLoading = true
        do {
            // 简单实现：遍历更新
            for package in outdatedPackages {
                if Self.verbose {
                    BrewManagerPlugin.logger.info("\(self.t) 正在更新: \(package.name)")
                }
                try await service.upgrade(name: package.name, isCask: package.isCask)
            }
            if Self.verbose {
                BrewManagerPlugin.logger.info("\(self.t) ✅ 全部更新完成")
            }
            await refresh()
        } catch {
            if Self.verbose {
                BrewManagerPlugin.logger.error("\(self.t) ❌ 批量更新失败: \(error.localizedDescription)")
            }
            errorMessage = String(localized: "Batch update failed: \(error.localizedDescription)", table: "BrewManager")
        }
        isLoading = false
    }
}

extension Task {
    func asAnyCancellable() -> AnyCancellable {
        return AnyCancellable {
            self.cancel()
        }
    }
}
