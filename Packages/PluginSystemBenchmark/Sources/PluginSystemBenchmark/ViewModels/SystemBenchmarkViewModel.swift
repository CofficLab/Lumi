import Foundation
import SwiftUI

/// 跑一轮基准测试的最小契约。
///
/// 抽出协议是为了让 ViewModel 的取消 / 失败状态可以注入替身验证，
/// 而不必真的跑一遍 CPU / 内存 / 磁盘负载。
protocol SystemBenchmarkRunning: Sendable {
    func run(progress: @escaping @Sendable (BenchmarkProgress) async -> Void) async throws -> BenchmarkReport
}

extension SystemBenchmarkRunner: SystemBenchmarkRunning {}

@MainActor
public final class SystemBenchmarkViewModel: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var progress: BenchmarkProgress = .preparing
    @Published public private(set) var report: BenchmarkReport?
    @Published public private(set) var errorMessage: String?

    /// 用户主动取消后的中性提示；与 `errorMessage` 互斥。
    ///
    /// 取消是用户行为，不是失败。混进错误横幅会让用户以为自己把测试跑挂了，
    /// 也会掩盖真正需要关注的失败信息。
    @Published public private(set) var cancellationMessage: String?

    private let runner: any SystemBenchmarkRunning
    private var task: Task<Void, Never>?

    public init() {
        self.runner = SystemBenchmarkRunner()
    }

    init(runner: any SystemBenchmarkRunning) {
        self.runner = runner
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        progress = .preparing
        report = nil
        errorMessage = nil
        cancellationMessage = nil

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
                cancellationMessage = BenchmarkLocalization.string("The test was cancelled before it finished.")
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
