import Foundation
import LLMKit
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel

final class ChunkCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

actor GatewayRejectionGate {
    private var buffered = ""
    private var suppressing = false

    func shouldSuppress(chunk: LumiStreamChunk) -> Bool {
        if suppressing {
            return true
        }
        if let content = chunk.content {
            buffered += content
            if FreeModelClaudeCodeEmulation.isGatewayRejection(buffered) {
                suppressing = true
                return true
            }
        }
        return false
    }
}
