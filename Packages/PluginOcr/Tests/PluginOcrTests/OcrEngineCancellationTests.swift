import Foundation
import Testing
@testable import PluginOcr

/// #270：取消 OCR 必须立刻释放等待方，不再等 Vision 推理自然结束。
@Suite("OcrEngine 取消")
struct OcrEngineCancellationTests {
    @Test("取消后等待方立刻收到 CancellationError，不吞掉迟到的推理结果")
    func cancellationStopsWaitingForInferencePromptly() async throws {
        let completion = InferenceCompletionBox()
        let inference = Task.detached {
            defer { completion.markFinished() }
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return "late result"
        }
        defer { inference.cancel() }

        let call = Task { try await OcrEngine.awaitInference(inference, completion: completion) }
        try await Task.sleep(nanoseconds: 200_000_000)

        let cancelStart = Date()
        call.cancel()
        do {
            _ = try await call.value
            Issue.record("Expected CancellationError after call.cancel()")
        } catch is CancellationError {
            #expect(Date().timeIntervalSince(cancelStart) < 2.0)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("推理任务自身的错误原样向外传递")
    func awaitInferenceRethrowsInferenceError() async throws {
        struct Boom: Error {}
        let completion = InferenceCompletionBox()
        let inference = Task.detached {
            defer { completion.markFinished() }
            throw Boom()
        }

        do {
            _ = try await OcrEngine.awaitInference(inference, completion: completion)
            Issue.record("Expected inference error to propagate")
        } catch is Boom {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
