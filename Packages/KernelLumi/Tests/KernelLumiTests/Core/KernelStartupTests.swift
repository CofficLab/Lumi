import Testing
@testable import KernelLumi

@Suite("Kernel Startup")
@MainActor
struct KernelStartupTests {
    @Test("精简宿主在 Agent 和 LLM 服务缺失时仍可启动")
    func minimalHostStartsWithoutAgentOrLLMServices() async throws {
        let kernel = KernelTestKit.makeKernel()
        kernel.requiresAllCoreServices = false

        try await kernel.startup()

        #expect(kernel.toolManager == nil)
        #expect(kernel.llmProvider == nil)
    }
}
