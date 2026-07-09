import Foundation
import Combine
import SwiftUI
import SuperLogKit
import LumiCoreKit

protocol BrewManagerServicing: Sendable {
    func checkInstalled() async -> Bool
    func listInstalled() async throws -> [BrewPackage]
    func getOutdated() async throws -> [BrewPackage]
    func search(query: String) async throws -> [BrewPackage]
    func install(name: String, isCask: Bool) async throws
    func uninstall(name: String, isCask: Bool) async throws
    func upgrade(name: String, isCask: Bool) async throws
}

struct LiveBrewManagerService: BrewManagerServicing {
    private let service: BrewService

    init(service: BrewService = .shared) {
        self.service = service
    }

    func checkInstalled() async -> Bool {
        await service.checkInstalled()
    }

    func listInstalled() async throws -> [BrewPackage] {
        try await service.listInstalled()
    }

    func getOutdated() async throws -> [BrewPackage] {
        try await service.getOutdated()
    }

    func search(query: String) async throws -> [BrewPackage] {
        try await service.search(query: query)
    }

    func install(name: String, isCask: Bool) async throws {
        try await service.install(name: name, isCask: isCask)
    }

    func uninstall(name: String, isCask: Bool) async throws {
        try await service.uninstall(name: name, isCask: isCask)
    }

    func upgrade(name: String, isCask: Bool) async throws {
        try await service.upgrade(name: name, isCask: isCask)
    }
}

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
    private let service: any BrewManagerServicing
    
    init(service: any BrewManagerServicing = LiveBrewManagerService(), autoCheckEnvironment: Bool = true) {
        self.service = service
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t) 初始化 BrewManagerViewModel")
            }
        }
        if autoCheckEnvironment {
            checkEnvironment()
        }
    }
    
    func checkEnvironment() {
        Task {
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.info("\(self.t) 检查 Homebrew 环境")
                }
            }
            isBrewInstalled = await service.checkInstalled()
            if isBrewInstalled {
                if Self.verbose {
                    if BrewManagerPlugin.verbose {
                                            BrewManagerPlugin.logger.info("\(self.t) Homebrew 已安装，开始刷新数据")
                    }
                }
                await refresh()
            } else {
                if Self.verbose {
                    if BrewManagerPlugin.verbose {
                                            BrewManagerPlugin.logger.error("\(self.t) ❌ Homebrew not detected")
                    }
                }
                errorMessage = LumiPluginLocalization.string("Homebrew not detected, please install Homebrew first.", bundle: .module)
            }
        }
    }
    
    func refresh() async {
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t)🔄 Starting to refresh package list")
            }
        }
        isLoading = true
        errorMessage = nil
        
        do {
            async let installed = service.listInstalled()
            async let outdated = service.getOutdated()
            
            let (installedList, outdatedList) = try await (installed, outdated)
            
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.info("\(self.t) ✅ Refresh complete: \(installedList.count) installed, \(outdatedList.count) outdated")
                }
            }
            
            self.installedPackages = installedList
            self.outdatedPackages = outdatedList
        } catch {
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.error("\(self.t) ❌ Refresh failed: \(error.localizedDescription)")
                }
            }
            self.errorMessage = LumiPluginLocalization.string("Refresh failed: \(error.localizedDescription)", bundle: .module)
        }
        
        isLoading = false
    }
    
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchCancellable?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }
        
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t) 🔍 触发搜索: \(self.searchText)")
            }
        }
        isLoading = true
        errorMessage = nil
        
        searchCancellable = Task { [service, query] in
            do {
                // 延迟 0.5s 防抖
                try await Task.sleep(nanoseconds: 500_000_000)
                
                if Self.verbose {
                    if BrewManagerPlugin.verbose {
                                            BrewManagerPlugin.logger.info("\(self.t) 执行搜索 API 调用: \(self.searchText)")
                    }
                }
                let results = try await service.search(query: query)
                
                if !Task.isCancelled && query == self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if Self.verbose {
                        if BrewManagerPlugin.verbose {
                                                    BrewManagerPlugin.logger.info("\(self.t) ✅ 搜索完成: 找到 \(results.count) 个结果")
                        }
                    }
                    self.searchResults = results
                    self.isLoading = false
                } else if !Task.isCancelled {
                    self.searchResults = []
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    if Self.verbose {
                        if BrewManagerPlugin.verbose {
                                                    BrewManagerPlugin.logger.error("\(self.t) ❌ 搜索失败: \(error.localizedDescription)")
                        }
                    }
                    self.errorMessage = LumiPluginLocalization.string("Search failed: \(error.localizedDescription)", bundle: .module)
                    self.isLoading = false
                }
            }
        }.asAnyCancellable()
    }
    
    func install(package: BrewPackage) async {
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t) ⬇️ 开始安装: \(package.name)")
            }
        }
        isLoading = true
        do {
            try await service.install(name: package.name, isCask: package.isCask)
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.info("\(self.t) ✅ 安装成功: \(package.name)")
                }
            }
            await refresh()
        } catch {
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.error("\(self.t) ❌ 安装失败: \(error.localizedDescription)")
                }
            }
            errorMessage = LumiPluginLocalization.string("Installation failed: \(error.localizedDescription)", bundle: .module)
        }
        isLoading = false
    }
    
    func uninstall(package: BrewPackage) async {
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t) 🗑️ 开始卸载: \(package.name)")
            }
        }
        isLoading = true
        do {
            try await service.uninstall(name: package.name, isCask: package.isCask)
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.info("\(self.t) ✅ 卸载成功: \(package.name)")
                }
            }
            await refresh()
        } catch {
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.error("\(self.t) ❌ 卸载失败: \(error.localizedDescription)")
                }
            }
            errorMessage = LumiPluginLocalization.string("Uninstallation failed: \(error.localizedDescription)", bundle: .module)
        }
        isLoading = false
    }
    
    func upgrade(package: BrewPackage) async {
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t) ⬆️ 开始更新: \(package.name)")
            }
        }
        isLoading = true
        do {
            try await service.upgrade(name: package.name, isCask: package.isCask)
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.info("\(self.t) ✅ 更新成功: \(package.name)")
                }
            }
            await refresh()
        } catch {
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.error("\(self.t) ❌ 更新失败: \(error.localizedDescription)")
                }
            }
            errorMessage = LumiPluginLocalization.string("Update failed: \(error.localizedDescription)", bundle: .module)
        }
        isLoading = false
    }
    
    func upgradeAll() async {
        if Self.verbose {
            if BrewManagerPlugin.verbose {
                            BrewManagerPlugin.logger.info("\(self.t) 🚀 开始全部更新 (\(self.outdatedPackages.count) 个包)")
            }
        }
        isLoading = true
        do {
            // 简单实现：遍历更新
            for package in outdatedPackages {
                if Self.verbose {
                    if BrewManagerPlugin.verbose {
                                            BrewManagerPlugin.logger.info("\(self.t) 正在更新: \(package.name)")
                    }
                }
                try await service.upgrade(name: package.name, isCask: package.isCask)
            }
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.info("\(self.t) ✅ 全部更新完成")
                }
            }
            await refresh()
        } catch {
            if Self.verbose {
                if BrewManagerPlugin.verbose {
                                    BrewManagerPlugin.logger.error("\(self.t) ❌ 批量更新失败: \(error.localizedDescription)")
                }
            }
            errorMessage = LumiPluginLocalization.string("Batch update failed: \(error.localizedDescription)", bundle: .module)
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
