import Foundation
import Darwin
import Testing
@testable import LumiPreviewKit

@Suite("LivePreviewEngine", .serialized)
struct PreviewEngineTests {

    @Test("完整的 scan → build → launch → render → refresh → stop 管线")
    func fullPreviewPipeline() async throws {
        let package = try makeTemporaryPackage(
            targetName: "PreviewTarget",
            source: """
            import SwiftUI

            struct TestPreviewView: View {
                var body: some View {
                    Text("Hello")
                }
            }

            #Preview("Test Preview") {
                TestPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Test Preview")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        let startResponse = await session.lastRenderResponse
        #expect(startResponse?.message == "Loaded preview view entry Test Preview")
        #expect(startResponse?.previewImagePNGBase64 != nil)
        let startMetrics = await session.performanceMetrics
        #expect(startMetrics.lastCompileDuration != nil)
        #expect(startMetrics.lastLoadDuration != nil)
        #expect(startMetrics.lastCompileUsedCache == false)

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        let refreshResponse = await session.lastRenderResponse
        #expect(refreshResponse?.message == "Loaded preview view entry Test Preview")
        #expect(refreshResponse?.previewImagePNGBase64 != nil)
        let refreshMetrics = await session.performanceMetrics
        #expect(refreshMetrics.lastCompileDuration != nil)
        #expect(refreshMetrics.lastLoadDuration != nil)
        #expect(refreshMetrics.lastRefreshDuration != nil)
        #expect(refreshMetrics.lastCompileUsedCache == true)

        await engine.stopPreview(session)
        #expect(await session.state == .stopped)
    }

    @Test("SPM target 跨文件 #Preview → 生成真实 NSView entry")
    func spmCrossFilePreviewUsesTargetSources() async throws {
        let package = try makeTemporaryPackage(
            targetName: "CrossFilePreviewTarget",
            source: """
            import SwiftUI

            #Preview("Cross File") {
                CrossFilePreviewView()
            }
            """,
            extraSources: [
                "CrossFilePreviewView.swift": """
                import SwiftUI

                struct CrossFilePreviewView: View {
                    var body: some View {
                        Text("Cross File")
                    }
                }
                """
            ]
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Cross File")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Cross File")
        #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)

        await engine.stopPreview(session)
    }

    @Test("编译失败 → session 状态变为 failed")
    func compileFailureMarksSessionFailed() async throws {
        let package = try makeTemporaryPackage(
            targetName: "BrokenPreviewTarget",
            source: """
            import SwiftUI

            struct BrokenPreviewView: View {
                var body: some View {
                    Text("Hello")
                }
            }

            #Preview("Broken") {
                BrokenPreviewView()
            }

            let broken =
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let engine = LumiPreviewPackage.LivePreviewEngine(
            hostExecutableURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-host-\(UUID().uuidString)")
        )
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let session = try await engine.startPreview(discoveries[0])
        guard case .failed(.compilationFailed(let message)) = await session.state else {
            Issue.record("Expected compilationFailed, got \(await session.state)")
            return
        }
        #expect(message.contains("TestView.swift"))
    }

    @Test("宿主进程崩溃后 refresh 自动重启")
    func refreshRestartsCrashedHost() async throws {
        let package = try makeTemporaryPackage(
            targetName: "RestartPreviewTarget",
            source: """
            import SwiftUI

            struct RestartPreviewView: View {
                var body: some View {
                    Text("Restart")
                }
            }

            #Preview("Restart") {
                RestartPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)

        guard let liveSession = session as? LumiPreviewPackage.LivePreviewSession else {
            Issue.record("Expected LumiPreviewPackage.LivePreviewSession")
            return
        }
        await liveSession.terminateHost()

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        #expect(await session.performanceMetrics.lastRefreshDuration != nil)
        #expect(await session.performanceMetrics.lastLoadDuration != nil)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Restart")

        await engine.stopPreview(session)
    }

    @Test("宿主进程崩溃后恢复的会话仍可重新进入 Live 并停止")
    func recoveredSessionCanReenterLiveAfterHostCrash() async throws {
        let package = try makeTemporaryPackage(
            targetName: "RecoveredLivePreviewTarget",
            source: """
            import SwiftUI

            struct RecoveredLivePreviewView: View {
                var body: some View {
                    Text("Recovered Live")
                }
            }

            #Preview("Recovered Live") {
                RecoveredLivePreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)

        try await engine.startLivePreview(session)
        #expect(await session.livePreviewInfo.state == .running)

        guard let liveSession = session as? LumiPreviewPackage.LivePreviewSession else {
            Issue.record("Expected LumiPreviewPackage.LivePreviewSession")
            return
        }

        await liveSession.terminateHost()
        let crashedConnection = await liveSession.hostConnection()
        if let crashedConnection {
            #expect(!(await crashedConnection.isRunning))
        }

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message?.contains("Recovered Live") == true)

        try await engine.startLivePreview(session)
        #expect(await session.livePreviewInfo.state == .running)

        await engine.stopPreview(session)
        #expect(await session.state == .stopped)
    }

    @Test("环境注入配置随预览会话启动、刷新和宿主重启保留")
    func environmentInjectionConfigurationSurvivesRefreshAndHostRestart() async throws {
        let package = try makeTemporaryPackage(
            targetName: "EnvironmentPreviewTarget",
            source: """
            import SwiftUI

            final class MockAppModel: ObservableObject {}

            struct EnvironmentPreviewView: View {
                @EnvironmentObject var model: MockAppModel

                var body: some View {
                    Text("Environment")
                }
            }

            #Preview("Environment") {
                EnvironmentPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let configuration = LumiPreviewPackage.PreviewRenderConfiguration(
            environmentInjections: [
                LumiPreviewPackage.PreviewEnvironmentInjection(
                    typeName: "MockAppModel",
                    mockIdentifier: "preview.mockAppModel",
                    displayName: "Preview Mock App Model"
                )
            ]
        )
        let session = try await engine.startPreview(discoveries[0], configuration: configuration)
        #expect(await session.state == .running)
        #expect(await session.configuration == configuration)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Environment")

        let updatedConfiguration = LumiPreviewPackage.PreviewRenderConfiguration(
            environmentInjections: [
                LumiPreviewPackage.PreviewEnvironmentInjection(
                    typeName: "MockAppModel",
                    mockIdentifier: "preview.updatedMockAppModel",
                    displayName: "Updated Mock App Model"
                )
            ]
        )
        try await engine.refreshPreview(session, configuration: updatedConfiguration)
        #expect(await session.state == .running)
        #expect(await session.configuration == updatedConfiguration)

        guard let liveSession = session as? LumiPreviewPackage.LivePreviewSession else {
            Issue.record("Expected LumiPreviewPackage.LivePreviewSession")
            return
        }
        await liveSession.terminateHost()

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        #expect(await session.configuration == updatedConfiguration)

        await engine.stopPreview(session)
    }

    @Test("Live 预览刷新遇到编译失败时保留上一份成功响应")
    func liveRefreshCompileFailureKeepsPreviousSuccessfulResponse() async throws {
        let package = try makeTemporaryPackage(
            targetName: "FailingLivePreviewTarget",
            source: """
            import SwiftUI

            struct FailingLivePreviewView: View {
                var body: some View {
                    Text("Stable")
                }
            }

            #Preview("Failing Live") {
                FailingLivePreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        try await engine.startLivePreview(session)
        let successfulResponse = await session.lastRenderResponse
        #expect(successfulResponse?.message == "Loaded preview view entry Failing Live")

        try """
        import SwiftUI

        struct FailingLivePreviewView: View {
            var body: some View {
                Text("Broken")
            }
        }

        #Preview("Failing Live") {
            FailingLivePreviewView()
        }

        let broken =
        """.write(to: package.sourceFile, atomically: true, encoding: .utf8)

        await #expect(throws: LumiPreviewPackage.PreviewError.self) {
            try await engine.refreshPreview(session)
        }

        guard case .failed = await session.state else {
            Issue.record("Expected failed state after broken refresh")
            return
        }

        let failedResponse = await session.lastRenderResponse
        #expect(failedResponse == successfulResponse)
        #expect(failedResponse?.message == "Loaded preview view entry Failing Live")

        await engine.stopPreview(session)
    }

    @Test("并发启动多个预览 → 共享构建并分别运行")
    func startsMultiplePreviewsConcurrently() async throws {
        let package = try makeTemporaryPackage(
            targetName: "ConcurrentPreviewTarget",
            source: """
            import SwiftUI

            struct FirstConcurrentPreviewView: View {
                var body: some View {
                    Text("First")
                }
            }

            struct SecondConcurrentPreviewView: View {
                var body: some View {
                    Text("Second")
                }
            }

            #Preview("First") {
                FirstConcurrentPreviewView()
            }

            #Preview("Second") {
                SecondConcurrentPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
            .sorted { $0.title < $1.title }
        #expect(discoveries.map(\.title) == ["First", "Second"])

        async let firstSession = engine.startPreview(discoveries[0])
        async let secondSession = engine.startPreview(discoveries[1])
        let sessions = try await [firstSession, secondSession]

        #expect(await sessions[0].state == .running)
        #expect(await sessions[1].state == .running)

        let metrics = await [
            sessions[0].performanceMetrics,
            sessions[1].performanceMetrics
        ]
        #expect(metrics.allSatisfy { $0.lastCompileDuration != nil })
        #expect(metrics.contains { $0.lastCompileUsedCache })

        await engine.stopPreview(sessions[0])
        await engine.stopPreview(sessions[1])
        #expect(await sessions[0].state == .stopped)
        #expect(await sessions[1].state == .stopped)
    }

    @Test("停止旧 session 不影响新 session 的 Live 预览")
    func stoppingOldSessionDoesNotAffectNewLiveSession() async throws {
        let package = try makeTemporaryPackage(
            targetName: "SwitchPreviewTarget",
            source: """
            import SwiftUI

            struct FirstSwitchPreviewView: View {
                var body: some View {
                    Text("First Live")
                }
            }

            struct SecondSwitchPreviewView: View {
                var body: some View {
                    Text("Second Live")
                }
            }

            #Preview("First Live") {
                FirstSwitchPreviewView()
            }

            #Preview("Second Live") {
                SecondSwitchPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
            .sorted { $0.title < $1.title }
        #expect(discoveries.map(\.title) == ["First Live", "Second Live"])

        let firstSession = try await engine.startPreview(discoveries[0])
        try await engine.startLivePreview(firstSession)
        let firstLiveInfo = await firstSession.livePreviewInfo
        #expect(firstLiveInfo.state == .running)
        #expect(firstLiveInfo.hostProcessID != nil)

        let secondSession = try await engine.startPreview(discoveries[1])
        try await engine.startLivePreview(secondSession)
        let secondLiveInfo = await secondSession.livePreviewInfo
        #expect(secondLiveInfo.state == .running)
        #expect(secondLiveInfo.hostProcessID != nil)
        #expect(secondLiveInfo.hostProcessID != firstLiveInfo.hostProcessID)

        await engine.stopPreview(firstSession)
        #expect(await firstSession.state == .stopped)

        #expect(await secondSession.state == .running)
        #expect(await secondSession.livePreviewInfo.state == .running)

        try await engine.refreshPreview(secondSession)
        #expect(await secondSession.state == .running)
        #expect(await secondSession.lastRenderResponse?.message?.contains("Second Live") == true)

        await engine.stopPreview(secondSession)
        #expect(await secondSession.state == .stopped)
    }

    @Test("停止旧 session 时仅回收旧 host，新 host 保持运行")
    func stoppingOldSessionOnlyTerminatesOldHost() async throws {
        let package = try makeTemporaryPackage(
            targetName: "SwitchPreviewHostTarget",
            source: """
            import SwiftUI

            struct FirstSwitchHostView: View {
                var body: some View {
                    Text("First Host")
                }
            }

            struct SecondSwitchHostView: View {
                var body: some View {
                    Text("Second Host")
                }
            }

            #Preview("First Host") {
                FirstSwitchHostView()
            }

            #Preview("Second Host") {
                SecondSwitchHostView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
            .sorted { $0.title < $1.title }
        #expect(discoveries.map(\.title) == ["First Host", "Second Host"])

        let firstSession = try await engine.startPreview(discoveries[0])
        try await engine.startLivePreview(firstSession)
        let firstConnection = await (firstSession as? LumiPreviewPackage.LivePreviewSession)?.hostConnection()
        let firstPID = await firstConnection?.processID

        let secondSession = try await engine.startPreview(discoveries[1])
        try await engine.startLivePreview(secondSession)
        let secondConnection = await (secondSession as? LumiPreviewPackage.LivePreviewSession)?.hostConnection()
        let secondPID = await secondConnection?.processID

        #expect(firstPID != nil)
        #expect(secondPID != nil)
        #expect(firstPID != secondPID)
        #expect(await firstConnection?.isRunning == true)
        #expect(await secondConnection?.isRunning == true)

        await engine.stopPreview(firstSession)
        #expect(await firstSession.state == .stopped)

        if let firstPID {
            try await waitForProcessExit(firstPID)
            #expect(!processExists(firstPID))
        }

        #expect(await secondConnection?.isRunning == true)
        if let secondPID {
            #expect(processExists(secondPID))
        }
        #expect(await secondSession.state == .running)

        await engine.stopPreview(secondSession)
        #expect(await secondSession.state == .stopped)
        if let secondPID {
            try await waitForProcessExit(secondPID)
        }
    }

    @Test("切换文件后旧 live window 不能残留，新 live window 仍可显示")
    func switchingFilesStopsOldLiveWindowWithoutBreakingNewOne() async throws {
        let package = try makeTemporaryPackage(
            targetName: "SwitchPreviewWindowTarget",
            source: """
            import SwiftUI

            struct FirstSwitchWindowView: View {
                var body: some View {
                    Text("First Window")
                }
            }

            struct SecondSwitchWindowView: View {
                var body: some View {
                    Text("Second Window")
                }
            }

            #Preview("First Window") {
                FirstSwitchWindowView()
            }

            #Preview("Second Window") {
                SecondSwitchWindowView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
            .sorted { $0.title < $1.title }
        #expect(discoveries.map(\.title) == ["First Window", "Second Window"])

        let firstSession = try await engine.startPreview(discoveries[0])
        try await engine.startLivePreview(firstSession)
        let firstConnection = await (firstSession as? LumiPreviewPackage.LivePreviewSession)?.hostConnection()

        let secondSession = try await engine.startPreview(discoveries[1])
        try await engine.startLivePreview(secondSession)
        let secondConnection = await (secondSession as? LumiPreviewPackage.LivePreviewSession)?.hostConnection()

        #expect(firstConnection != nil)
        #expect(secondConnection != nil)

        await engine.stopPreview(firstSession)
        #expect(await firstSession.state == .stopped)

        await #expect(throws: Error.self) {
            _ = try await firstConnection?.requestShowLivePreview()
        }

        let secondShowResponse = try await secondConnection?.requestShowLivePreview()
        #expect(secondShowResponse?.success == true)
        #expect(await secondSession.livePreviewInfo.state == .running)

        await engine.stopPreview(secondSession)
        #expect(await secondSession.state == .stopped)
    }

    @Test("反复编辑刷新后不泄漏 host 进程且缓存目录不会无界增长")
    func repeatedPreviewCyclesDoNotLeakHostsOrUnboundedCaches() async throws {
        let package = try makeTemporaryPackage(
            targetName: "RepeatedCyclePreviewTarget",
            source: sourceForCycledText("Cycle A")
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let baselineCacheEntries = previewEntryCacheDirectoryNames()
        let variants = ["Cycle A", "Cycle B", "Cycle A", "Cycle B"]
        var observedPIDs = Set<Int32>()

        for text in variants {
            try sourceForCycledText(text).write(to: package.sourceFile, atomically: true, encoding: .utf8)

            let discoveries = await engine.discoverPreviews(in: package.sourceFile)
            #expect(discoveries.count == 1)
            #expect(discoveries[0].title == "Repeated Cycle")

            let session = try await engine.startPreview(discoveries[0])
            #expect(await session.state == .running)

            try await engine.startLivePreview(session)
            #expect(await session.livePreviewInfo.state == .running)

            let connection = await (session as? LumiPreviewPackage.LivePreviewSession)?.hostConnection()
            let processID = await connection?.processID
            #expect(processID != nil)
            if let processID {
                observedPIDs.insert(processID)
                #expect(processExists(processID))
            }

            try await engine.refreshPreview(session)
            #expect(await session.state == .running)
            #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)
            #expect(await session.lastRenderResponse?.message?.contains("Repeated Cycle") == true)

            await engine.stopPreview(session)
            #expect(await session.state == .stopped)

            if let processID {
                try await waitForProcessExit(processID, timeout: 4)
                #expect(!processExists(processID))
            }
        }

        let finalCacheEntries = previewEntryCacheDirectoryNames()
        let newCacheEntries = finalCacheEntries.subtracting(baselineCacheEntries)
        #expect(observedPIDs.count == variants.count)
        #expect(newCacheEntries.count <= 8)
    }

    @Test("Xcode 项目 scan → build → launch → render → stop 管线")
    func fullXcodePreviewPipeline() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "XcodePreviewTool",
            previewSource: """
            import SwiftUI

            struct XcodePreviewView: View {
                var body: some View {
                    Text("Xcode Preview")
                }
            }

            #Preview("Xcode Preview") {
                XcodePreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: project.previewFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Xcode Preview")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Xcode Preview")
        #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)
        let metrics = await session.performanceMetrics
        #expect(metrics.lastCompileDuration != nil)
        #expect(metrics.lastLoadDuration != nil)
        #expect(metrics.lastCompileUsedCache == false)

        await engine.stopPreview(session)
        #expect(await session.state == .stopped)
    }

    @Test("Xcode 项目跨文件 #Preview → 生成真实 NSView entry")
    func xcodeCrossFilePreviewUsesTargetSources() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "XcodeCrossFilePreviewTool",
            previewSource: """
            import SwiftUI

            #Preview("Xcode Cross File") {
                XcodeCrossFilePreviewView()
            }
            """,
            extraSources: [
                "XcodeCrossFilePreviewView.swift": """
                import SwiftUI

                struct XcodeCrossFilePreviewView: View {
                    var body: some View {
                        Text("Xcode Cross File")
                    }
                }
                """
            ]
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: project.previewFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Xcode Cross File")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Xcode Cross File")
        #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)

        await engine.stopPreview(session)
    }

    @Test("真实 view entry 构建失败 → 返回结构化诊断")
    func previewViewEntryFailureReturnsStructuredDiagnostics() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEntryDiagnostics-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("main.swift")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
            import SwiftUI

            print("top-level executable entry")

            #Preview("Broken Entry") {
                Text("Fallback")
            }
            """.write(to: sourceFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let hostExecutableURL = try buildHostExecutable()
        let connection = try await LumiPreviewPackage.PreviewHostProcess().launch(executableURL: hostExecutableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let source = try String(contentsOf: sourceFile, encoding: .utf8)
        let discoveries = LumiPreviewPackage.PreviewScanner().scan(fileURL: sourceFile, sourceText: source)
        #expect(discoveries.count == 1)

        let entryURL = try await LumiPreviewPackage.PreviewEntryBuilder().buildEntry(
            for: discoveries[0],
            configuration: .empty,
            buildStrategy: .incremental(fileURL: sourceFile, compileCommand: "")
        )
        let response = try await connection.requestLoadPreviewEntry(
            at: entryURL,
            symbolName: LumiPreviewPackage.PreviewEntryBuilder.symbolName
        )

        #expect(response.message == "Loaded preview entry Broken Entry")
        #expect(response.isFallback == true)
        #expect(response.diagnostics?.contains("expressions are not allowed at the top level") == true)
        #expect(response.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    @Test("扫描不存在的文件返回空预览")
    func discoverMissingFileReturnsEmptyList() async {
        let engine = LumiPreviewPackage.LivePreviewEngine(
            hostExecutableURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-host-\(UUID().uuidString)")
        )

        let previews = await engine.discoverPreviews(
            in: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-preview-\(UUID().uuidString).swift")
        )

        #expect(previews.isEmpty)
    }

    @Test("Live 控制 API 通过活动连接转发请求")
    func liveControlRequestsUseActiveHostConnection() async throws {
        let engine = LumiPreviewPackage.LivePreviewEngine(
            hostExecutableURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("unused-host-\(UUID().uuidString)")
        )
        let session = LumiPreviewPackage.LivePreviewSession(discovery: sampleDiscovery())
        let connection = RecordingHostConnection()
        await session.setHostConnection(connection)

        try await engine.startLivePreview(session)
        #expect(connection.commands == [.startLivePreview])
        #expect(await session.livePreviewInfo.state == .running)
        #expect(await session.livePreviewInfo.hostWindowNumber == 42)

        connection.captureResponse = LumiPreviewPackage.RenderResponse(
            success: true,
            previewID: "captured-preview",
            message: "Captured frame",
            previewImagePNGBase64: "png",
            livePreviewEnabled: true,
            liveWindowNumber: 43
        )
        let captureResponse = try await engine.capturePreviewFrame(session)
        #expect(captureResponse.message == "Captured frame")
        #expect(connection.lastCaptureIncludeImageFallback == true)
        #expect(await session.lastRenderResponse?.previewID == "captured-preview")
        #expect(await session.livePreviewInfo.state == .running)
        #expect(await session.livePreviewInfo.hostWindowNumber == 43)

        _ = try await engine.capturePreviewFrame(session, includeImageFallback: false)
        #expect(connection.lastCaptureIncludeImageFallback == false)

        try await engine.updateLiveFrame(session, x: 10, y: 20, width: 300, height: 200, scale: 2)
        try await engine.showLivePreview(session)
        try await engine.hideLivePreview(session)
        try await engine.reloadLivePreview(
            session,
            dylibURL: URL(fileURLWithPath: "/tmp/PreviewEntry.dylib")
        )
        try await engine.stopLivePreview(session)

        #expect(connection.commands == [
            .startLivePreview,
            .captureFrame,
            .captureFrame,
            .updateLiveFrame,
            .showLivePreview,
            .hideLivePreview,
            .reloadLivePreview,
            .stopLivePreview
        ])
        #expect(connection.lastFrame == LumiPreviewPackage.LiveFrameRequest(x: 10, y: 20, width: 300, height: 200, scale: 2))
        #expect(connection.lastReloadPath == "/tmp/PreviewEntry.dylib")
        #expect(await session.livePreviewInfo.state == .available)
        #expect(await session.livePreviewInfo.hostWindowNumber == nil)
    }

    @Test("Live 控制 API 在无活动连接时安全返回或抛错")
    func liveControlWithoutConnectionIsSafe() async throws {
        let engine = LumiPreviewPackage.LivePreviewEngine(
            hostExecutableURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("unused-host-\(UUID().uuidString)")
        )
        let session = LumiPreviewPackage.LivePreviewSession(discovery: sampleDiscovery())

        await #expect(throws: LumiPreviewPackage.PreviewError.self) {
            try await engine.startLivePreview(session)
        }
        await #expect(throws: LumiPreviewPackage.PreviewError.self) {
            try await engine.capturePreviewFrame(session)
        }

        try await engine.updateLiveFrame(session, x: 0, y: 0, width: 1, height: 1)
        try await engine.showLivePreview(session)
        try await engine.hideLivePreview(session)
        try await engine.reloadLivePreview(
            session,
            dylibURL: URL(fileURLWithPath: "/tmp/missing.dylib")
        )
        try await engine.stopLivePreview(session)
    }

    @Test("Live 启动和 reload 失败会抛出运行时错误")
    func liveControlFailuresThrowRuntimeErrors() async throws {
        let engine = LumiPreviewPackage.LivePreviewEngine(
            hostExecutableURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("unused-host-\(UUID().uuidString)")
        )
        let session = LumiPreviewPackage.LivePreviewSession(discovery: sampleDiscovery())
        let connection = RecordingHostConnection()
        connection.startLiveResponse = LumiPreviewPackage.RenderResponse(success: false, message: "start failed")
        await session.setHostConnection(connection)

        await #expect(throws: LumiPreviewPackage.PreviewError.self) {
            try await engine.startLivePreview(session)
        }

        connection.startLiveResponse = LumiPreviewPackage.RenderResponse(success: true, livePreviewEnabled: true)
        connection.reloadResponse = LumiPreviewPackage.RenderResponse(success: false, message: "reload failed")
        await #expect(throws: LumiPreviewPackage.PreviewError.self) {
            try await engine.reloadLivePreview(
                session,
                dylibURL: URL(fileURLWithPath: "/tmp/PreviewEntry.dylib")
            )
        }
    }

    private func makeTemporaryPackage(
        targetName: String,
        source: String,
        extraSources: [String: String] = [:]
    ) throws -> (directory: URL, sourceFile: URL) {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEngineTests-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("TestView.swift")

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(targetName)Package",
            platforms: [.macOS(.v14)],
            targets: [
                .target(name: "\(targetName)")
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try source.write(to: sourceFile, atomically: true, encoding: .utf8)
        for (fileName, content) in extraSources {
            let extraSourceFile = sourceDirectory.appendingPathComponent(fileName)
            try FileManager.default.createDirectory(
                at: extraSourceFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: extraSourceFile, atomically: true, encoding: .utf8)
        }

        return (packageDirectory, sourceFile)
    }

    private func sampleDiscovery() -> LumiPreviewPackage.PreviewDiscovery {
        LumiPreviewPackage.PreviewDiscovery(
            id: "sample:1:0",
            title: "Sample",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Sample.swift"),
            lineNumber: 1,
            endLineNumber: 3,
            bodySource: "Text(\"Sample\")",
            sourceText: "#Preview { Text(\"Sample\") }"
        )
    }

    private func sourceForCycledText(_ text: String) -> String {
        """
        import SwiftUI

        struct RepeatedCyclePreviewView: View {
            var body: some View {
                Text("\(text)")
            }
        }

        #Preview("Repeated Cycle") {
            RepeatedCyclePreviewView()
        }
        """
    }

    private func makeTemporaryXcodeProject(
        targetName: String,
        previewSource: String,
        extraSources: [String: String] = [:]
    ) throws -> (rootDirectory: URL, previewFile: URL) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEngine-Xcode-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("\(targetName).xcodeproj", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)
        let mainFile = sourceDirectory.appendingPathComponent("main.swift")
        let previewFile = sourceDirectory.appendingPathComponent("PreviewView.swift")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try "print(\"preview host build target\")\n".write(to: mainFile, atomically: true, encoding: .utf8)
        try previewSource.write(to: previewFile, atomically: true, encoding: .utf8)
        for (fileName, content) in extraSources {
            let extraSourceFile = sourceDirectory.appendingPathComponent(fileName)
            try FileManager.default.createDirectory(
                at: extraSourceFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: extraSourceFile, atomically: true, encoding: .utf8)
        }

        try xcodeProjectContent(
            targetName: targetName,
            extraSwiftFiles: extraSources.keys.sorted()
        ).write(
            to: projectURL.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )

        return (rootDirectory, previewFile)
    }

    private func xcodeProjectContent(targetName: String, extraSwiftFiles: [String]) -> String {
        let extraFileReferences = extraSwiftFiles.enumerated().map { index, fileName in
            """
            \t\t\(pbxID(0x100 + index)) = {
            \t\t\tisa = PBXFileReference;
            \t\t\tlastKnownFileType = sourcecode.swift;
            \t\t\tpath = Sources/\(fileName);
            \t\t\tsourceTree = "<group>";
            \t\t};
            """
        }.joined(separator: "\n")
        let extraGroupChildren = extraSwiftFiles.enumerated().map { index, _ in
            "\t\t\t\t\(pbxID(0x100 + index)),"
        }.joined(separator: "\n")
        let extraBuildFiles = extraSwiftFiles.enumerated().map { index, _ in
            """
            \t\t\(pbxID(0x200 + index)) = {
            \t\t\tisa = PBXBuildFile;
            \t\t\tfileRef = \(pbxID(0x100 + index));
            \t\t};
            """
        }.joined(separator: "\n")
        let extraSourceFiles = extraSwiftFiles.enumerated().map { index, _ in
            "\t\t\t\t\(pbxID(0x200 + index)),"
        }.joined(separator: "\n")

        return """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {};
        \tobjectVersion = 56;
        \tobjects = {
        \t\t000000000000000000000001 = {
        \t\t\tisa = PBXProject;
        \t\t\tattributes = {
        \t\t\t\tLastSwiftUpdateCheck = 1500;
        \t\t\t\tLastUpgradeCheck = 1500;
        \t\t\t};
        \t\t\tbuildConfigurationList = 000000000000000000000010;
        \t\t\tcompatibilityVersion = "Xcode 14.0";
        \t\t\tdevelopmentRegion = en;
        \t\t\thasScannedForEncodings = 0;
        \t\t\tknownRegions = (en, Base);
        \t\t\tmainGroup = 000000000000000000000002;
        \t\t\tproductRefGroup = 000000000000000000000003;
        \t\t\tprojectDirPath = "";
        \t\t\tprojectRoot = "";
        \t\t\ttargets = (000000000000000000000004);
        \t\t};
        \t\t000000000000000000000002 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t000000000000000000000005,
        \t\t\t\t000000000000000000000006,
        \(extraGroupChildren)
        \t\t\t\t000000000000000000000003,
        \t\t\t);
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000003 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (000000000000000000000007);
        \t\t\tname = Products;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000005 = {
        \t\t\tisa = PBXFileReference;
        \t\t\tlastKnownFileType = sourcecode.swift;
        \t\t\tpath = Sources/main.swift;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000006 = {
        \t\t\tisa = PBXFileReference;
        \t\t\tlastKnownFileType = sourcecode.swift;
        \t\t\tpath = Sources/PreviewView.swift;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \(extraFileReferences)
        \t\t000000000000000000000007 = {
        \t\t\tisa = PBXFileReference;
        \t\t\texplicitFileType = compiled.mach-o.executable;
        \t\t\tincludeInIndex = 0;
        \t\t\tpath = \(targetName);
        \t\t\tsourceTree = BUILT_PRODUCTS_DIR;
        \t\t};
        \t\t000000000000000000000008 = {
        \t\t\tisa = PBXBuildFile;
        \t\t\tfileRef = 000000000000000000000005;
        \t\t};
        \t\t000000000000000000000009 = {
        \t\t\tisa = PBXBuildFile;
        \t\t\tfileRef = 000000000000000000000006;
        \t\t};
        \(extraBuildFiles)
        \t\t00000000000000000000000A = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t\t000000000000000000000008,
        \t\t\t\t000000000000000000000009,
        \(extraSourceFiles)
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        \t\t000000000000000000000004 = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = 000000000000000000000020;
        \t\t\tbuildPhases = (00000000000000000000000A);
        \t\t\tbuildRules = ();
        \t\t\tdependencies = ();
        \t\t\tname = \(targetName);
        \t\t\tproductName = \(targetName);
        \t\t\tproductReference = 000000000000000000000007;
        \t\t\tproductType = "com.apple.product-type.tool";
        \t\t};
        \t\t000000000000000000000010 = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t000000000000000000000011,
        \t\t\t\t000000000000000000000012,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Debug;
        \t\t};
        \t\t000000000000000000000011 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tSDKROOT = macosx;
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t000000000000000000000012 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tSDKROOT = macosx;
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        \t\t000000000000000000000020 = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t000000000000000000000021,
        \t\t\t\t000000000000000000000022,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Debug;
        \t\t};
        \t\t000000000000000000000021 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGNING_ALLOWED = NO;
        \t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
        \t\t\t\tPRODUCT_NAME = \(targetName);
        \t\t\t\tSWIFT_VERSION = 6.0;
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t000000000000000000000022 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGNING_ALLOWED = NO;
        \t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
        \t\t\t\tPRODUCT_NAME = \(targetName);
        \t\t\t\tSWIFT_VERSION = 6.0;
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        \t};
        \trootObject = 000000000000000000000001;
        }
        """
    }

    private func pbxID(_ value: Int) -> String {
        String(format: "%024X", value)
    }

    private func buildHostExecutable() throws -> URL {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scratchPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEngineHost-build-\(UUID().uuidString)", isDirectory: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift",
            "build",
            "--package-path",
            packageDirectory.path,
            "--scratch-path",
            scratchPath.path,
            "--product",
            "LumiPreviewHostApp"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw LumiPreviewPackage.PreviewError.compilationFailed(message: output)
        }

        guard let executableURL = findHostExecutable(in: scratchPath) else {
            throw LumiPreviewPackage.PreviewError.buildProductNotFound
        }

        return executableURL
    }

    private func findHostExecutable(in scratchPath: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: scratchPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == "LumiPreviewHostApp" {
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private func waitForProcessExit(_ processID: Int32, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !processExists(processID) {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        Issue.record("Process \(processID) still exists after timeout")
    }

    private func processExists(_ processID: Int32) -> Bool {
        if kill(processID, 0) == 0 {
            return true
        }
        return errno != ESRCH
    }

    private func previewEntryCacheDirectoryNames() -> Set<String> {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-PreviewEntryCache", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return Set(
            entries.compactMap { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return values?.isDirectory == true ? url.lastPathComponent : nil
            }
        )
    }
}

private final class RecordingHostConnection: LumiPreviewPackage.HostConnection, @unchecked Sendable {
    enum Command: Equatable {
        case render
        case refresh
        case captureFrame
        case loadDylib
        case loadPreviewEntry
        case startLivePreview
        case updateLiveFrame
        case showLivePreview
        case hideLivePreview
        case reloadLivePreview
        case stopLivePreview
        case terminate
    }

    var commands: [Command] = []
    var running = true
    var lastFrame: LumiPreviewPackage.LiveFrameRequest?
    var lastReloadPath: String?
    var lastCaptureIncludeImageFallback: Bool?
    var startLiveResponse = LumiPreviewPackage.RenderResponse(
        success: true,
        livePreviewEnabled: true,
        liveWindowNumber: 42
    )
    var captureResponse = LumiPreviewPackage.RenderResponse(success: true)
    var reloadResponse = LumiPreviewPackage.RenderResponse(success: true, livePreviewEnabled: true)

    var isRunning: Bool {
        get async {
            running
        }
    }

    var processID: Int32 {
        get async {
            1234
        }
    }

    func requestRender(
        discovery: LumiPreviewPackage.PreviewDiscovery,
        configuration: LumiPreviewPackage.PreviewRenderConfiguration
    ) async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.render)
        return LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestRefresh() async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.refresh)
        return LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestCaptureFrame(includeImageFallback: Bool) async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.captureFrame)
        lastCaptureIncludeImageFallback = includeImageFallback
        return captureResponse
    }

    func requestLoadDylib(at dylibURL: URL) async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.loadDylib)
        return LumiPreviewPackage.RenderResponse(success: true)
    }

    func requestLoadPreviewEntry(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.loadPreviewEntry)
        return LumiPreviewPackage.RenderResponse(success: true, livePreviewEnabled: true)
    }

    func requestStartLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.startLivePreview)
        return startLiveResponse
    }

    func requestUpdateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.updateLiveFrame)
        lastFrame = LumiPreviewPackage.LiveFrameRequest(x: x, y: y, width: width, height: height, scale: scale)
        return LumiPreviewPackage.RenderResponse(success: true, livePreviewEnabled: true)
    }

    func requestShowLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.showLivePreview)
        return LumiPreviewPackage.RenderResponse(success: true, livePreviewEnabled: true)
    }

    func requestHideLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.hideLivePreview)
        return LumiPreviewPackage.RenderResponse(success: true, livePreviewEnabled: true)
    }

    func requestReloadLivePreview(at dylibURL: URL, symbolName: String) async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.reloadLivePreview)
        lastReloadPath = dylibURL.path
        return reloadResponse
    }

    func requestStopLivePreview() async throws -> LumiPreviewPackage.RenderResponse {
        commands.append(.stopLivePreview)
        return LumiPreviewPackage.RenderResponse(success: true)
    }

    func terminate() async {
        commands.append(.terminate)
        running = false
    }
}
