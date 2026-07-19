import Foundation
import SwiftUI

public protocol RegistryManagerServicing: Sendable {
    func getCurrentRegistry(for type: RegistryType) async throws -> String
    func setRegistry(for type: RegistryType, url: String) async throws
}

extension RegistryService: RegistryManagerServicing {}

@MainActor
public class RegistryManagerViewModel: ObservableObject {
    @Published var registries: [RegistryType: String] = [:]
    @Published var isLoading: [RegistryType: Bool] = [:]
    @Published var errorMsg: String?
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    private let service: any RegistryManagerServicing
    private var operationIDs: [RegistryType: UUID] = [:]
    private var setTasks: [RegistryType: Task<Void, Error>] = [:]
    private var toastTask: Task<Void, Never>?
    
    // Presets
    public let presets: [RegistryType: [RegistrySource]] = [
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
    
    public init(service: any RegistryManagerServicing = RegistryService.shared, autoRefresh: Bool = true) {
        self.service = service

        if autoRefresh {
            Task {
                await refreshAll()
            }
        }
    }
    
    public func refreshAll() async {
        for type in RegistryType.allCases {
            await refresh(type)
        }
    }
    
    public func refresh(_ type: RegistryType) async {
        let operationID = beginOperation(for: type)
        isLoading[type] = true
        do {
            let current = try await service.getCurrentRegistry(for: type)
            guard isCurrentOperation(operationID, for: type) else { return }
            registries[type] = current
        } catch {
            guard isCurrentOperation(operationID, for: type) else { return }
            registries[type] = "Unknown"
        }
        finishOperation(operationID, for: type)
    }
    
    public func setRegistry(_ type: RegistryType, source: RegistrySource) async {
        let operationID = beginOperation(for: type)
        isLoading[type] = true
        let previousSetTask = setTasks[type]
        let setTask = Task { [service, previousSetTask, type, url = source.url] in
            do {
                try await previousSetTask?.value
            } catch {
                // A newer choice should still be attempted even if an older change failed.
            }
            try await service.setRegistry(for: type, url: url)
        }
        setTasks[type] = setTask

        do {
            try await setTask.value
            guard isCurrentOperation(operationID, for: type) else { return }
            registries[type] = source.url
            
            if type == .docker {
                showToast(message: LumiPluginLocalization.string("Docker registry updated. Please restart Docker Desktop.", bundle: .module))
            } else {
                let message = LumiPluginLocalization.string("Switched {type} registry to {name}", bundle: .module)
                    .replacingOccurrences(of: "{type}", with: type.name)
                    .replacingOccurrences(of: "{name}", with: source.name)
                showToast(message: message)
            }
        } catch {
            guard isCurrentOperation(operationID, for: type) else { return }
            errorMsg = LumiPluginLocalization.string("Failed to set {type}: {error}", bundle: .module)
                .replacingOccurrences(of: "{type}", with: type.name)
                .replacingOccurrences(of: "{error}", with: error.localizedDescription)
            let message = LumiPluginLocalization.string("Failed: {error}", bundle: .module)
                .replacingOccurrences(of: "{error}", with: error.localizedDescription)
            showToast(message: message)
        }
        setTasks[type] = nil
        finishOperation(operationID, for: type)
    }
    
    public func showToast(message: String) {
        toastTask?.cancel()
        toastMessage = message
        showToast = true
        // Auto hide handled by view or simple timer
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            showToast = false
        }
    }

    private func beginOperation(for type: RegistryType) -> UUID {
        let operationID = UUID()
        operationIDs[type] = operationID
        return operationID
    }

    private func isCurrentOperation(_ operationID: UUID, for type: RegistryType) -> Bool {
        operationIDs[type] == operationID
    }

    private func finishOperation(_ operationID: UUID, for type: RegistryType) {
        guard isCurrentOperation(operationID, for: type) else { return }
        isLoading[type] = false
        operationIDs[type] = nil
    }

    deinit {
        setTasks.values.forEach { $0.cancel() }
        toastTask?.cancel()
    }
}
