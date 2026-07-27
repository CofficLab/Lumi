import Foundation

enum LumiKernelToolExecutionContextStorage {
    @TaskLocal
    static var current: LumiToolExecutionContextState?
}

extension LumiKernelContainer {
    public nonisolated func withToolExecutionContextState<T>(
        _ state: LumiToolExecutionContextState,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await LumiKernelToolExecutionContextStorage.$current.withValue(state) {
            try await operation()
        }
    }

    private nonisolated var activeToolExecutionState: LumiToolExecutionContextState? {
        LumiKernelToolExecutionContextStorage.current
    }
}

extension LumiKernelContainer {
    public nonisolated var conversationID: UUID {
        guard let state = activeToolExecutionState else {
            fatalError("Tool execution kernel is not active")
        }
        return state.conversationID
    }

    public nonisolated var toolCallID: String {
        guard let state = activeToolExecutionState else {
            fatalError("Tool execution kernel is not active")
        }
        return state.toolCallID
    }

    public nonisolated var toolName: String {
        guard let state = activeToolExecutionState else {
            fatalError("Tool execution kernel is not active")
        }
        return state.toolName
    }

    public nonisolated var currentProjectPath: String? {
        activeToolExecutionState?.currentProjectPath
    }

    public nonisolated var allowedDirectories: [String] {
        activeToolExecutionState?.allowedDirectories ?? []
    }

    public nonisolated var language: LumiLanguagePreference {
        activeToolExecutionState?.language ?? .english
    }

    public nonisolated var verbosity: String? {
        activeToolExecutionState?.verbosity
    }

    public nonisolated var isCancelled: Bool {
        activeToolExecutionState?.isCancelled ?? Task.isCancelled
    }

    public nonisolated func isPathAllowed(_ path: String) -> Bool {
        activeToolExecutionState?.isPathAllowed(path) ?? true
    }

    public nonisolated func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }

    @discardableResult
    public nonisolated func onCancel(_ handler: @escaping LumiToolExecutionContextState.CancellationHandler) -> UUID? {
        activeToolExecutionState?.onCancel(handler)
    }

    public nonisolated func removeCancellationHandler(_ id: UUID?) {
        activeToolExecutionState?.removeCancellationHandler(id)
    }

    public nonisolated func cancel() {
        activeToolExecutionState?.cancel()
    }

    public nonisolated func attachImage(_ image: LumiImageAttachment) {
        activeToolExecutionState?.attachImage(image)
    }

    public nonisolated func attachImages(_ images: [LumiImageAttachment]) {
        activeToolExecutionState?.attachImages(images)
    }

    public nonisolated func collectImages() -> [LumiImageAttachment] {
        activeToolExecutionState?.collectImages() ?? []
    }
}
