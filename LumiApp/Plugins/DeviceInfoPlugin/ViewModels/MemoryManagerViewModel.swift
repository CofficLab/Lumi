import Combine
import Foundation
import MagicKit
import os

@MainActor
class MemoryManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = false

    @Published var memoryUsagePercentage: Double = 0.0
    @Published var usedMemory: String = "0 GB"
    @Published var totalMemory: String = "0 GB"
    @Published var rawTotalMemory: UInt64 = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        startMonitoring()
    }

    deinit {
        Task { @MainActor in
            MemoryService.shared.stopMonitoring()
        }
    }

    func startMonitoring() {
        MemoryService.shared.startMonitoring()

        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory, MemoryService.shared.$totalMemory)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pct, used, total in
                guard let self else { return }
                self.memoryUsagePercentage = pct
                self.usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
                self.totalMemory = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
                self.rawTotalMemory = total
            }
            .store(in: &cancellables)
    }
}
