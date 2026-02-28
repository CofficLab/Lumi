import Foundation
import SwiftUI

@MainActor
class RegistryManagerViewModel: ObservableObject {
    @Published var registries: [RegistryType: String] = [:]
    @Published var isLoading: [RegistryType: Bool] = [:]
    @Published var errorMsg: String?
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    // Presets
    let presets: [RegistryType: [RegistrySource]] = [
        .npm: [
            .init(name: "Official", url: "https://registry.npmjs.org/", type: .npm),
            .init(name: "Taobao (New)", url: "https://registry.npmmirror.com/", type: .npm),
            .init(name: "Tencent", url: "https://mirrors.cloud.tencent.com/npm/", type: .npm)
        ],
        .yarn: [
            .init(name: "Official", url: "https://registry.yarnpkg.com/", type: .yarn),
            .init(name: "Taobao (New)", url: "https://registry.npmmirror.com/", type: .yarn),
            .init(name: "Tencent", url: "https://mirrors.cloud.tencent.com/npm/", type: .yarn)
        ],
        .pnpm: [
             .init(name: "Official", url: "https://registry.npmjs.org/", type: .pnpm),
             .init(name: "Taobao (New)", url: "https://registry.npmmirror.com/", type: .pnpm),
        ],
        .docker: [
            .init(name: "Docker Hub", url: "https://index.docker.io/v1/", type: .docker),
            .init(name: "163", url: "http://hub-mirror.c.163.com", type: .docker),
            .init(name: "USTC", url: "https://docker.mirrors.ustc.edu.cn", type: .docker),
            .init(name: "Tencent", url: "https://mirror.ccs.tencentyun.com", type: .docker)
        ],
        .pip: [
            .init(name: "PyPI", url: "https://pypi.org/simple", type: .pip),
            .init(name: "Tuna (Tsinghua)", url: "https://pypi.tuna.tsinghua.edu.cn/simple", type: .pip),
            .init(name: "Aliyun", url: "https://mirrors.aliyun.com/pypi/simple/", type: .pip),
            .init(name: "Douban", url: "https://pypi.doubanio.com/simple/", type: .pip)
        ],
        .go: [
            .init(name: "Official", url: "https://proxy.golang.org,direct", type: .go),
            .init(name: "Goproxy.cn", url: "https://goproxy.cn,direct", type: .go),
            .init(name: "Aliyun", url: "https://mirrors.aliyun.com/goproxy/,direct", type: .go)
        ]
    ]
    
    init() {
        Task {
            await refreshAll()
        }
    }
    
    func refreshAll() async {
        for type in RegistryType.allCases {
            await refresh(type)
        }
    }
    
    func refresh(_ type: RegistryType) async {
        isLoading[type] = true
        do {
            let current = try await RegistryService.shared.getCurrentRegistry(for: type)
            registries[type] = current
        } catch {
            registries[type] = "Unknown"
        }
        isLoading[type] = false
    }
    
    func setRegistry(_ type: RegistryType, source: RegistrySource) async {
        isLoading[type] = true
        do {
            try await RegistryService.shared.setRegistry(for: type, url: source.url)
            registries[type] = source.url
            
            if type == .docker {
                showToast(message: "Docker registry updated. Please restart Docker Desktop.")
            } else {
                showToast(message: "Switched \(type.name) registry to \(source.name)")
            }
        } catch {
            errorMsg = "Failed to set \(type.name): \(error.localizedDescription)"
            showToast(message: "Failed: \(error.localizedDescription)")
        }
        isLoading[type] = false
    }
    
    func showToast(message: String) {
        toastMessage = message
        showToast = true
        // Auto hide handled by view or simple timer
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            showToast = false
        }
    }
}
