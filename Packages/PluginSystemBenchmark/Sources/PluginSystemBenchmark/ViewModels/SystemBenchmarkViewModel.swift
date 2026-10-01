import Foundation
import SwiftUI

@MainActor
public final class SystemBenchmarkViewModel: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var progress: BenchmarkProgress = .preparing
    @Published public private(set) var report: BenchmarkReport?
    @Published public private(set) var errorMessage: String?

    private let runner: SystemBenchmarkRunner
    private var task: Task<Void, Never>?

    public init(runner: SystemBenchmarkRunner = SystemBenchmarkRunner()) {
        self.runner = runner
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        progress = .preparing
        report = nil
        errorMessage = nil

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let nextReport = try await runner.run { [weak self] nextProgress in
                    await MainActor.run {
                        self?.progress = nextProgress
                    }
                }
                report = nextReport
            } catch is CancellationError {
                errorMessage = BenchmarkLocalization.string("Test cancelled")
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
            task = nil
        }
    }

    public func cancel() {
        task?.cancel()
    }
}
