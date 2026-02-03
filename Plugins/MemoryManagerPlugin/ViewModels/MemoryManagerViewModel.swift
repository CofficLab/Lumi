import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class MemoryManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "💾"
    static let verbose = false
    
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
            .sink { [weak self] (pct, used, total) in
                guard let self = self else { return }
                self.memoryUsagePercentage = pct
                self.usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
                self.totalMemory = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
                self.rawTotalMemory = total
            }
            .store(in: &cancellables)
    }
}
