import Foundation
import Combine
import SwiftUI
import MagicKit
import OSLog

@MainActor
class BrewManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🍺"
    nonisolated static let verbose = true

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
            os_log("\(self.t) 初始化 BrewManagerViewModel")
        }
        checkEnvironment()
    }
    
    func checkEnvironment() {
        Task {
            if Self.verbose {
                os_log("\(self.t) 检查 Homebrew 环境")
            }
            isBrewInstalled = await service.checkInstalled()
            if isBrewInstalled {
                if Self.verbose {
                    os_log("\(self.t) Homebrew 已安装，开始刷新数据")
                }
                await refresh()
            } else {
                if Self.verbose {
                    os_log("\(self.t) ❌ 未检测到 Homebrew")
                }
                errorMessage = "未检测到 Homebrew，请先安装 Homebrew。"
            }
        }
    }
    
    func refresh() async {
        if Self.verbose {
            os_log("\(self.t) 🔄 开始刷新包列表")
        }
        isLoading = true
        errorMessage = nil
        
        do {
            async let installed = service.listInstalled()
            async let outdated = service.getOutdated()
            
            let (installedList, outdatedList) = try await (installed, outdated)
            
            if Self.verbose {
                os_log("\(self.t) ✅ 刷新完成: 已安装 \(installedList.count) 个, 待更新 \(outdatedList.count) 个")
            }
            
            self.installedPackages = installedList
            self.outdatedPackages = outdatedList
        } catch {
            if Self.verbose {
                os_log("\(self.t) ❌ 刷新失败: \(error.localizedDescription)")
            }
            self.errorMessage = "刷新失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        if Self.verbose {
            os_log("\(self.t) 🔍 触发搜索: \(self.searchText)")
        }
        isLoading = true
        searchCancellable?.cancel()
        
        searchCancellable = Task {
            do {
                // 延迟 0.5s 防抖
                try await Task.sleep(nanoseconds: 500_000_000)
                
                if Self.verbose {
                    os_log("\(self.t) 执行搜索 API 调用: \(self.searchText)")
                }
                let results = try await service.search(query: searchText)
                
                if !Task.isCancelled {
                    if Self.verbose {
                        os_log("\(self.t) ✅ 搜索完成: 找到 \(results.count) 个结果")
                    }
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    if Self.verbose {
                        os_log("\(self.t) ❌ 搜索失败: \(error.localizedDescription)")
                    }
                    self.errorMessage = "搜索失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }.asAnyCancellable()
    }
    
    func install(package: BrewPackage) async {
        if Self.verbose {
            os_log("\(self.t) ⬇️ 开始安装: \(package.name)")
        }
        isLoading = true
        do {
            try await service.install(name: package.name, isCask: package.isCask)
            if Self.verbose {
                os_log("\(self.t) ✅ 安装成功: \(package.name)")
            }
            await refresh()
        } catch {
            if Self.verbose {
                os_log("\(self.t) ❌ 安装失败: \(error.localizedDescription)")
            }
            errorMessage = "安装失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func uninstall(package: BrewPackage) async {
        if Self.verbose {
            os_log("\(self.t) 🗑️ 开始卸载: \(package.name)")
        }
        isLoading = true
        do {
            try await service.uninstall(name: package.name, isCask: package.isCask)
            if Self.verbose {
                os_log("\(self.t) ✅ 卸载成功: \(package.name)")
            }
            await refresh()
        } catch {
            if Self.verbose {
                os_log("\(self.t) ❌ 卸载失败: \(error.localizedDescription)")
            }
            errorMessage = "卸载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func upgrade(package: BrewPackage) async {
        if Self.verbose {
            os_log("\(self.t) ⬆️ 开始更新: \(package.name)")
        }
        isLoading = true
        do {
            try await service.upgrade(name: package.name, isCask: package.isCask)
            if Self.verbose {
                os_log("\(self.t) ✅ 更新成功: \(package.name)")
            }
            await refresh()
        } catch {
            if Self.verbose {
                os_log("\(self.t) ❌ 更新失败: \(error.localizedDescription)")
            }
            errorMessage = "更新失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func upgradeAll() async {
        if Self.verbose {
            os_log("\(self.t) 🚀 开始全部更新 (\(self.outdatedPackages.count) 个包)")
        }
        isLoading = true
        do {
            // 简单实现：遍历更新
            for package in outdatedPackages {
                if Self.verbose {
                    os_log("\(self.t) 正在更新: \(package.name)")
                }
                try await service.upgrade(name: package.name, isCask: package.isCask)
            }
            if Self.verbose {
                os_log("\(self.t) ✅ 全部更新完成")
            }
            await refresh()
        } catch {
            if Self.verbose {
                os_log("\(self.t) ❌ 批量更新失败: \(error.localizedDescription)")
            }
            errorMessage = "批量更新失败: \(error.localizedDescription)"
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
