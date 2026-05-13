import Foundation
import LumiPreviewKit

@MainActor
final class EditorPreviewRemoteEmbeddedFrameStream {
    typealias FrameHandler = @MainActor (LumiPreviewPackage.RenderResponse, String) async -> Void
    typealias FailureHandler = @MainActor (String, Error) async -> Void

    private let intervalNanoseconds: UInt64
    private var frameTask: Task<Void, Never>?
    private var isCapturing = false

    init(intervalNanoseconds: UInt64 = 250_000_000) {
        self.intervalNanoseconds = intervalNanoseconds
    }

    deinit {
        frameTask?.cancel()
    }

    var isRunning: Bool {
        frameTask != nil
    }

    func start(
        session: any LumiPreviewPackage.PreviewSession,
        engine: LumiPreviewPackage.LivePreviewEngine,
        reason: String,
        includeImageFallback: @escaping @MainActor () -> Bool = { true },
        onFrame: @escaping FrameHandler,
        onFailure: @escaping FailureHandler
    ) {
        guard frameTask == nil else { return }

        EditorPreviewRemotePlugin.logger.info(
            "Starting embedded remote live frame stream: \(reason, privacy: .public)")
        frameTask = Task { [weak self, intervalNanoseconds] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self.capture(
                    session: session,
                    engine: engine,
                    reason: "embedded live frame tick",
                    includeImageFallback: includeImageFallback(),
                    onFrame: onFrame,
                    onFailure: onFailure
                )
            }
        }
    }

    func captureOnce(
        session: any LumiPreviewPackage.PreviewSession,
        engine: LumiPreviewPackage.LivePreviewEngine,
        reason: String,
        includeImageFallback: Bool = true,
        onFrame: @escaping FrameHandler,
        onFailure: @escaping FailureHandler
    ) async {
        await capture(
            session: session,
            engine: engine,
            reason: reason,
            includeImageFallback: includeImageFallback,
            onFrame: onFrame,
            onFailure: onFailure
        )
    }

    func stop() {
        frameTask?.cancel()
        frameTask = nil
        isCapturing = false
    }

    private func capture(
        session: any LumiPreviewPackage.PreviewSession,
        engine: LumiPreviewPackage.LivePreviewEngine,
        reason: String,
        includeImageFallback: Bool,
        onFrame: @escaping FrameHandler,
        onFailure: @escaping FailureHandler
    ) async {
        guard !isCapturing else {
            EditorPreviewRemotePlugin.logger.debug(
                "Skipping embedded remote live frame capture while another capture is running: \(reason, privacy: .public)")
            return
        }
        isCapturing = true
        defer {
            isCapturing = false
        }

        do {
            let response = try await engine.capturePreviewFrame(
                session,
                includeImageFallback: includeImageFallback
            )
            guard !Task.isCancelled else { return }
            await onFrame(response, reason)
        } catch {
            guard !Task.isCancelled else { return }
            await onFailure(reason, error)
        }
    }
}
