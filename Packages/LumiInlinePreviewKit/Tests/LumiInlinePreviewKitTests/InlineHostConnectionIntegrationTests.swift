import IOSurface
import XCTest
@testable import LumiInlinePreviewKit

private actor FrameCollector {
    private(set) var frames: [LumiInlinePreviewFacade.IOSurfaceFrame] = []
    private(set) var sawInteractivePolicy = false
    private(set) var errorMessages: [String] = []
    private(set) var entryLoadedEvents: [(success: Bool, message: String?)] = []
    private(set) var debugStates: [String] = []
    private(set) var cursorShapes: [LumiInlinePreviewFacade.PreviewCursorShape] = []

    func append(_ frame: LumiInlinePreviewFacade.IOSurfaceFrame) {
        frames.append(frame)
    }
    func notePolicy(_ policy: LumiInlinePreviewFacade.FrameStreamPolicy) {
        if policy == .interactive { sawInteractivePolicy = true }
    }
    func noteError(_ message: String) {
        errorMessages.append(message)
    }
    func noteEntryLoaded(success: Bool, message: String?) {
        entryLoadedEvents.append((success, message))
    }
    func noteDebugState(_ state: String) {
        debugStates.append(state)
    }
    func noteCursorShape(_ shape: LumiInlinePreviewFacade.PreviewCursorShape) {
        cursorShapes.append(shape)
    }
    var firstFrame: LumiInlinePreviewFacade.IOSurfaceFrame? { frames.first }
    var frameCount: Int { frames.count }
    var firstFailedEntry: (success: Bool, message: String?)? {
        entryLoadedEvents.first(where: { !$0.success })
    }
}

/// 端到端集成测试：
/// 启动真实的 `LumiInlinePreviewHostApp` 子进程，
/// 验证 ping、startFrameStream、frameProduced 事件、surface 跨进程可解析。
///
/// 依赖：测试运行前必须先 `swift build` 产出 host 二进制。
/// `InlineHostExecutableResolver` 的 SPM `.build` 解析路径会自动找到它。
final class InlineHostConnectionIntegrationTests: XCTestCase {

    func test_endToEnd_pingAndFrameStream() async throws {
        guard let url = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: url)

        // 1. ping
        let pong = try await connection.send(.ping)
        XCTAssertTrue(pong.success)
        XCTAssertEqual(pong.message, "pong")

        // 2. 订阅事件流到一个隔离的 actor 收集器
        let collector = FrameCollector()
        let frameExpectation = expectation(description: "received at least 3 frames")
        let policyExpectation = expectation(description: "stream policy switched to interactive")
        var pendingPolicyExpectation: XCTestExpectation? = policyExpectation
        var pendingFrameExpectation: XCTestExpectation? = frameExpectation

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .frameProduced(let frame):
                    await collector.append(frame)
                    let count = await collector.frameCount
                    if count >= 3, let exp = pendingFrameExpectation {
                        pendingFrameExpectation = nil
                        exp.fulfill()
                    }
                case .streamStateChanged(let policy):
                    await collector.notePolicy(policy)
                    if policy == .interactive, let exp = pendingPolicyExpectation {
                        pendingPolicyExpectation = nil
                        exp.fulfill()
                    }
                case .error(let message):
                    await collector.noteError(message)
                case .entryLoaded(let success, let message):
                    await collector.noteEntryLoaded(success: success, message: message)
                case .entryDebugState(let state):
                    await collector.noteDebugState(state)
                case .cursorChanged(let shape):
                    await collector.noteCursorShape(shape)
                }
            }
        }

        // 3. 启动帧流
        let startResponse = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(startResponse.success)

        await fulfillment(of: [policyExpectation, frameExpectation], timeout: 5)

        // 4. 验证 surface 跨进程可解析
        let resolvedFirstFrame = await collector.firstFrame
        let firstFrame = try XCTUnwrap(resolvedFirstFrame)
        let surface = IOSurfaceLookup(IOSurfaceID(firstFrame.surfaceID))
        XCTAssertNotNil(surface, "Cross-process IOSurface lookup should succeed")
        if let surface {
            XCTAssertEqual(IOSurfaceGetWidth(surface), firstFrame.width)
            XCTAssertEqual(IOSurfaceGetHeight(surface), firstFrame.height)
        }

        // 5. 关闭
        let stopResponse = try await connection.send(.stopFrameStream)
        XCTAssertTrue(stopResponse.success)

        eventTask.cancel()
        await connection.terminate()
    }

    /// 验证 `loadDylib` 对不存在路径的失败处理：
    /// - 同步响应 success=false
    /// - 子进程推送一条 `.entryLoaded(success: false, …)` 事件
    /// - 子进程不会因此崩溃，后续 `ping` 仍可正常往返
    func test_loadDylib_missingFile_returnsErrorEvent() async throws {
        guard let url = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: url)

        let collector = FrameCollector()
        let entryFailExpectation = expectation(description: "received entryLoaded(success: false)")
        var pendingEntryFail: XCTestExpectation? = entryFailExpectation

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .frameProduced(let frame):
                    await collector.append(frame)
                case .streamStateChanged(let policy):
                    await collector.notePolicy(policy)
                case .error(let message):
                    await collector.noteError(message)
                case .entryLoaded(let success, let message):
                    await collector.noteEntryLoaded(success: success, message: message)
                    if !success, let exp = pendingEntryFail {
                        pendingEntryFail = nil
                        exp.fulfill()
                    }
                case .entryDebugState(let state):
                    await collector.noteDebugState(state)
                case .cursorChanged(let shape):
                    await collector.noteCursorShape(shape)
                }
            }
        }

        let response = try await connection.send(
            .loadDylib(path: "/tmp/__definitely_not_a_real_dylib__.dylib", symbolName: "lumi_preview_make_nsview")
        )
        XCTAssertFalse(response.success, "loading non-existent dylib should fail synchronously")
        XCTAssertNotNil(response.message)

        await fulfillment(of: [entryFailExpectation], timeout: 3)

        let failure = await collector.firstFailedEntry
        XCTAssertNotNil(failure, "should have received entryLoaded(success: false) event")

        // 子进程仍存活
        let pong = try await connection.send(.ping)
        XCTAssertTrue(pong.success)

        eventTask.cancel()
        await connection.terminate()
    }

    /// 端到端正路径：编译 `PreviewDylibFixture.swift` → 启动子进程 →
    /// `loadDylib` → 等到 `entryLoaded(success: true)` 与至少一帧产出。
    ///
    /// 编译开销 ~5s；如果 `swiftc` 不可用或编译失败，会被 `XCTSkip` 跳过，
    /// 不阻塞日常迭代。
    func test_loadDylib_fixture_loadsAndProducesFrames() async throws {
        guard let hostURL = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let dylibURL = try compileFixtureDylib()
        defer { try? FileManager.default.removeItem(at: dylibURL) }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: hostURL)

        let collector = FrameCollector()
        let entryLoadedExpectation = expectation(description: "received entryLoaded(success: true)")
        let frameAfterLoadExpectation = expectation(description: "received frame after load")
        var pendingEntryLoaded: XCTestExpectation? = entryLoadedExpectation
        var pendingFrameAfterLoad: XCTestExpectation? = frameAfterLoadExpectation
        let loadIssuedFlag = AsyncFlag()

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .frameProduced(let frame):
                    await collector.append(frame)
                    let loadIssued = await loadIssuedFlag.value
                    if loadIssued, let exp = pendingFrameAfterLoad {
                        pendingFrameAfterLoad = nil
                        exp.fulfill()
                    }
                case .streamStateChanged(let policy):
                    await collector.notePolicy(policy)
                case .error(let message):
                    await collector.noteError(message)
                case .entryLoaded(let success, let message):
                    await collector.noteEntryLoaded(success: success, message: message)
                    if success, message == nil, let exp = pendingEntryLoaded {
                        pendingEntryLoaded = nil
                        exp.fulfill()
                    }
                case .entryDebugState(let state):
                    await collector.noteDebugState(state)
                case .cursorChanged(let shape):
                    await collector.noteCursorShape(shape)
                }
            }
        }

        // 1. 起流
        let start = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(start.success)

        // 2. 加载 dylib
        await loadIssuedFlag.set(true)
        let loadResponse = try await connection.send(
            .loadDylib(path: dylibURL.path, symbolName: "lumi_preview_make_nsview")
        )
        XCTAssertTrue(loadResponse.success, "loadDylib failed: \(loadResponse.message ?? "nil")")

        await fulfillment(of: [entryLoadedExpectation, frameAfterLoadExpectation], timeout: 5)

        // 3. unload，子进程恢复 demo
        let unloadResponse = try await connection.send(.unloadDylib)
        XCTAssertTrue(unloadResponse.success)

        eventTask.cancel()
        await connection.terminate()
    }

    /// 端到端验证用户 entry 的可选调试状态符号：
    /// load fixture → 读取初始状态 → 转发输入事件 → 再读取状态，
    /// 证明跨进程输入确实改变了 entry 内部状态。
    func test_entryDebugState_reflectsForwardedInput() async throws {
        guard let hostURL = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let dylibURL = try compileFixtureDylib()
        defer { try? FileManager.default.removeItem(at: dylibURL) }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: hostURL)

        let collector = FrameCollector()
        let entryLoadedExpectation = expectation(description: "fixture entry loaded")
        var pendingEntryLoaded: XCTestExpectation? = entryLoadedExpectation

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .frameProduced(let frame):
                    await collector.append(frame)
                case .streamStateChanged(let policy):
                    await collector.notePolicy(policy)
                case .error(let message):
                    await collector.noteError(message)
                case .entryLoaded(let success, let message):
                    await collector.noteEntryLoaded(success: success, message: message)
                    if success, message == nil, let exp = pendingEntryLoaded {
                        pendingEntryLoaded = nil
                        exp.fulfill()
                    }
                case .entryDebugState(let state):
                    await collector.noteDebugState(state)
                case .cursorChanged(let shape):
                    await collector.noteCursorShape(shape)
                }
            }
        }

        let start = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(start.success)

        let loadResponse = try await connection.send(
            .loadDylib(path: dylibURL.path, symbolName: "lumi_preview_make_nsview")
        )
        XCTAssertTrue(loadResponse.success, "loadDylib failed: \(loadResponse.message ?? "nil")")
        await fulfillment(of: [entryLoadedExpectation], timeout: 5)

        let initialState = try await connection.send(.requestEntryDebugState)
        XCTAssertTrue(initialState.success)
        XCTAssertTrue(initialState.message?.contains("mouseDown=0;keyDown=0;drop=0;lastKey=") == true, initialState.message ?? "nil")

        let mouseResponse = try await connection.send(.forwardInputEvent(.mouse(.init(
            phase: .entered,
            button: .left,
            x: 80,
            y: 80,
            clickCount: 0,
            modifiers: []
        ))))
        XCTAssertTrue(mouseResponse.success)

        let clickResponse = try await connection.send(.forwardInputEvent(.mouse(.init(
            phase: .down,
            button: .left,
            x: 80,
            y: 80,
            clickCount: 1,
            modifiers: []
        ))))
        XCTAssertTrue(clickResponse.success)

        let keyResponse = try await connection.send(.forwardInputEvent(.key(.init(
            phase: .down,
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            modifiers: []
        ))))
        XCTAssertTrue(keyResponse.success)

        let textInputResponse = try await connection.send(.forwardInputEvent(.textInput(.init(
            phase: .insertText,
            text: "中",
            replacementRange: .notFound
        ))))
        XCTAssertTrue(textInputResponse.success)

        let finalState = try await connection.send(.requestEntryDebugState)
        XCTAssertTrue(finalState.success)
        XCTAssertTrue(finalState.message?.contains("first=a中") == true, finalState.message ?? "nil")
        XCTAssertTrue(finalState.message?.contains("focus=first") == true, finalState.message ?? "nil")

        let errors = await collector.errorMessages
        XCTAssertTrue(errors.isEmpty, "subprocess pushed errors during debug state test: \(errors)")

        eventTask.cancel()
        await connection.terminate()
    }

    func test_dragAndDropEvent_reachesLoadedFixture() async throws {
        guard let hostURL = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let dylibURL = try compileFixtureDylib()
        defer { try? FileManager.default.removeItem(at: dylibURL) }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: hostURL)

        let collector = FrameCollector()
        let entryLoadedExpectation = expectation(description: "fixture entry loaded for drop")
        var pendingEntryLoaded: XCTestExpectation? = entryLoadedExpectation

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .frameProduced(let frame):
                    await collector.append(frame)
                case .streamStateChanged(let policy):
                    await collector.notePolicy(policy)
                case .error(let message):
                    await collector.noteError(message)
                case .entryLoaded(let success, let message):
                    await collector.noteEntryLoaded(success: success, message: message)
                    if success, message == nil, let exp = pendingEntryLoaded {
                        pendingEntryLoaded = nil
                        exp.fulfill()
                    }
                case .entryDebugState(let state):
                    await collector.noteDebugState(state)
                case .cursorChanged(let shape):
                    await collector.noteCursorShape(shape)
                }
            }
        }

        let start = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(start.success)

        let loadResponse = try await connection.send(
            .loadDylib(path: dylibURL.path, symbolName: "lumi_preview_make_nsview")
        )
        XCTAssertTrue(loadResponse.success, "loadDylib failed: \(loadResponse.message ?? "nil")")
        await fulfillment(of: [entryLoadedExpectation], timeout: 5)

        let dropResponse = try await connection.send(.forwardInputEvent(.dragAndDrop(.init(
            phase: .perform,
            x: 120,
            y: 90,
            items: [.string("fixture-drop")],
            modifiers: []
        ))))
        XCTAssertTrue(dropResponse.success)

        let finalState = try await connection.send(.requestEntryDebugState)
        XCTAssertTrue(finalState.success)
        XCTAssertTrue(finalState.message?.contains("drop=1") == true, finalState.message ?? "nil")
        XCTAssertTrue(finalState.message?.contains("lastDrop=fixture-drop") == true, finalState.message ?? "nil")

        let errors = await collector.errorMessages
        XCTAssertTrue(errors.isEmpty, "subprocess pushed errors during drag-and-drop test: \(errors)")

        eventTask.cancel()
        await connection.terminate()
    }

    // MARK: - 私有：dylib 编译

    /// 用 `swiftc` 把 fixture 源文件编译成 `/tmp/LumiInlinePreviewFixture-<uuid>.dylib`。
    private func compileFixtureDylib() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixtureURL = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/PreviewDylibFixture.swift")

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("PreviewDylibFixture.swift not found at \(fixtureURL.path)")
        }

        let sdkProcess = Process()
        sdkProcess.launchPath = "/usr/bin/xcrun"
        sdkProcess.arguments = ["--show-sdk-path", "--sdk", "macosx"]
        let sdkPipe = Pipe()
        sdkProcess.standardOutput = sdkPipe
        sdkProcess.standardError = Pipe()
        do {
            try sdkProcess.run()
        } catch {
            throw XCTSkip("xcrun not available: \(error.localizedDescription)")
        }
        sdkProcess.waitUntilExit()
        guard sdkProcess.terminationStatus == 0 else {
            throw XCTSkip("xcrun --show-sdk-path failed (status \(sdkProcess.terminationStatus))")
        }
        let sdkPath = String(
            data: sdkPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !sdkPath.isEmpty else {
            throw XCTSkip("xcrun --show-sdk-path returned empty path")
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LumiInlinePreviewFixture-\(UUID().uuidString).dylib")

        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #else
        arch = "x86_64"
        #endif

        let swiftc = Process()
        swiftc.launchPath = "/usr/bin/xcrun"
        swiftc.arguments = [
            "swiftc",
            "-emit-library",
            "-O",
            "-module-name", "PreviewDylibFixture",
            "-sdk", sdkPath,
            "-target", "\(arch)-apple-macosx14.0",
            "-o", outputURL.path,
            fixtureURL.path
        ]
        let stderr = Pipe()
        swiftc.standardError = stderr
        swiftc.standardOutput = Pipe()
        try swiftc.run()
        swiftc.waitUntilExit()

        guard swiftc.terminationStatus == 0 else {
            let log = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            throw XCTSkip("swiftc failed (\(swiftc.terminationStatus)):\n\(log)")
        }
        return outputURL
    }
}

private actor AsyncFlag {
    private(set) var value: Bool = false
    func set(_ newValue: Bool) { value = newValue }
}
