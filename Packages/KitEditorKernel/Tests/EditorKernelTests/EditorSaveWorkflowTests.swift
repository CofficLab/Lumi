import Foundation
import LanguageServerProtocol
import Testing

@testable import EditorKernel

// MARK: - Helpers

/// 可跨并发边界写入的标记盒（`writeFile` 回调是 `@Sendable`）。
private final class FlagBox: @unchecked Sendable {
    var value = false
}

/// 轮询等待条件成立（保存流程通过 Task 派发回调）。
@MainActor
private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool,
    timeout: TimeInterval = 3
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

private func makeTemporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("editorkernel-save-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

// MARK: - Workflow controller

@MainActor
@Suite("EditorSaveWorkflowController")
struct EditorSaveWorkflowControllerExtraTests {

    @Test("有未保存改动时才触发立即保存")
    func savesNowOnlyWhenDirty() {
        let controller = EditorSaveWorkflowController()
        var saveCount = 0
        var logs: [String] = []

        controller.saveNowIfNeeded(
            hasUnsavedChanges: false,
            reason: "quit",
            fileName: "a.swift",
            verbose: true,
            log: { logs.append($0) },
            runSave: { saveCount += 1 }
        )
        #expect(saveCount == 0)
        #expect(logs.isEmpty)

        controller.saveNowIfNeeded(
            hasUnsavedChanges: true,
            reason: "quit",
            fileName: "a.swift",
            verbose: true,
            log: { logs.append($0) },
            runSave: { saveCount += 1 }
        )
        #expect(saveCount == 1)
        #expect(logs.count == 1)
        #expect(logs.first?.contains("触发立即保存") == true)
        #expect(logs.first?.contains("quit") == true)
        #expect(logs.first?.contains("a.swift") == true)
    }

    @Test("非 verbose 模式不记录日志")
    func quietModeSkipsLogging() {
        let controller = EditorSaveWorkflowController()
        var logs: [String] = []
        var saveCount = 0

        controller.saveNowIfNeeded(
            hasUnsavedChanges: true,
            reason: "quit",
            fileName: nil,
            verbose: false,
            log: { logs.append($0) },
            runSave: { saveCount += 1 }
        )

        #expect(saveCount == 1)
        #expect(logs.isEmpty)
    }

    @Test("正在保存时不重复执行保存任务")
    func skipsSaveTaskWhileSaving() {
        let controller = EditorSaveWorkflowController()
        var runCount = 0

        controller.saveNow(saveState: .saving, runSaveTask: { runCount += 1 })
        #expect(runCount == 0)

        controller.saveNow(saveState: .idle, runSaveTask: { runCount += 1 })
        #expect(runCount == 1)

        controller.saveNow(saveState: .saved, runSaveTask: { runCount += 1 })
        #expect(runCount == 2)
    }

    @Test("url 为 nil 时不执行保存并记录失败日志")
    func performSaveWithoutURL() {
        let controller = EditorSaveWorkflowController()
        var infos: [String] = []
        var errors: [String] = []
        var states: [EditorSaveState] = []

        controller.performSave(
            content: "text",
            url: nil,
            verbose: true,
            logInfo: { infos.append($0) },
            logError: { errors.append($0) },
            setSaveState: { states.append($0) },
            saveController: EditorSaveController(),
            saveStateController: EditorSaveStateController(),
            markPersistedText: { _ in },
            clearConflict: {},
            syncSession: {},
            scheduleSuccessClear: {},
            notifyDidSave: { _ in },
            setHasUnsavedChanges: { _ in }
        )

        #expect(infos.count == 1)
        #expect(infos.first?.contains("url 为 nil") == true)
        #expect(errors.isEmpty)
        #expect(states.isEmpty)
    }

    @Test("保存成功时写入文件并推进状态")
    func performSaveSucceeds() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("main.swift")
        try "old".write(to: fileURL, atomically: true, encoding: .utf8)

        let controller = EditorSaveWorkflowController()
        var states: [EditorSaveState] = []
        var persisted: [String] = []
        var notified: [String] = []
        var unsavedFlags: [Bool] = []
        var conflictCleared = false
        var synced = false
        var clearScheduled = false

        controller.performSave(
            content: "new content",
            url: fileURL,
            verbose: true,
            logInfo: { _ in },
            logError: { _ in },
            setSaveState: { states.append($0) },
            saveController: EditorSaveController(),
            saveStateController: EditorSaveStateController(),
            markPersistedText: { persisted.append($0) },
            clearConflict: { conflictCleared = true },
            syncSession: { synced = true },
            scheduleSuccessClear: { clearScheduled = true },
            notifyDidSave: { notified.append($0) },
            setHasUnsavedChanges: { unsavedFlags.append($0) }
        )

        #expect(await waitUntil { states.count >= 2 })

        let written = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(written == "new content")
        #expect(states.first == .saving)
        #expect(states.last == .saved)
        #expect(persisted == ["new content"])
        #expect(notified == ["new content"])
        #expect(unsavedFlags == [false])
        #expect(conflictCleared)
        #expect(synced)
        #expect(clearScheduled)
    }

    @Test("文件已不存在时报告失败并进入 error 状态")
    func performSaveFailsWhenFileMissing() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appendingPathComponent("gone.swift")

        let controller = EditorSaveWorkflowController()
        var errors: [String] = []
        var states: [EditorSaveState] = []
        var clearScheduled = false

        controller.performSave(
            content: "text",
            url: missing,
            verbose: false,
            logInfo: { _ in },
            logError: { errors.append($0) },
            setSaveState: { states.append($0) },
            saveController: EditorSaveController(),
            saveStateController: EditorSaveStateController(),
            markPersistedText: { _ in },
            clearConflict: {},
            syncSession: {},
            scheduleSuccessClear: { clearScheduled = true },
            notifyDidSave: { _ in },
            setHasUnsavedChanges: { _ in }
        )

        // `setSaveState(.saving)` 会立即发生，必须等错误回调到达。
        #expect(await waitUntil { !errors.isEmpty })

        #expect(errors.count == 1)
        #expect(errors.first?.contains("文件不存在") == true)
        #expect(states.last == .error(EditorStatusMessageCatalog.fileNotFound()))
        #expect(clearScheduled)
    }

    @Test("写入失败时报告错误并进入 error 状态")
    func performSaveFailsWhenWriteFails() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        // 用目录占位，写入必然失败。
        let directoryURL = root.appendingPathComponent("as-directory", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let controller = EditorSaveWorkflowController()
        var errors: [String] = []
        var states: [EditorSaveState] = []
        var synced = false

        controller.performSave(
            content: "text",
            url: directoryURL,
            verbose: false,
            logInfo: { _ in },
            logError: { errors.append($0) },
            setSaveState: { states.append($0) },
            saveController: EditorSaveController(),
            saveStateController: EditorSaveStateController(),
            markPersistedText: { _ in },
            clearConflict: {},
            syncSession: { synced = true },
            scheduleSuccessClear: {},
            notifyDidSave: { _ in },
            setHasUnsavedChanges: { _ in }
        )

        #expect(await waitUntil { !errors.isEmpty })

        #expect(errors.count == 1)
        #expect(states.last != nil)
        if case .error = states.last { } else {
            Issue.record("expected .error state, got \(String(describing: states.last))")
        }
        #expect(synced)
    }

    @Test("prepareAndSaveNow 在内容或文件缺失时直接返回")
    func prepareAndSaveNowRequiresContentAndURL() async {
        let controller = EditorSaveWorkflowController()
        let saveController = EditorSaveController()
        var performed = false

        await controller.prepareAndSaveNow(
            currentContent: nil,
            fileURL: URL(fileURLWithPath: "/tmp/a.swift"),
            saveController: saveController,
            options: EditorSavePipelineOptions(
                textParticipants: .init(trimTrailingWhitespace: false, insertFinalNewline: false),
                formatOnSave: false,
                organizeImportsOnSave: false,
                fixAllOnSave: false
            ),
            tabSize: 4,
            insertSpaces: true,
            currentFileURL: { nil },
            prepareFormatting: { _, _, _ in nil },
            applyPreparedSaveText: { _ in },
            currentText: { nil },
            diagnostics: { [] },
            requestCodeActions: { _, _, _ in [] },
            resolveCodeAction: { _ in nil },
            isCodeActionResolveSupported: false,
            applyWorkspaceEdit: { _ in },
            performSave: { _, _ in performed = true }
        )

        #expect(performed == false)
    }
}

// MARK: - Save controller

@MainActor
@Suite("EditorSaveController")
struct EditorSaveControllerExtraTests {

    @Test("pipelineOptions 透传各开关")
    func buildsPipelineOptions() {
        let controller = EditorSaveController()
        let options = controller.pipelineOptions(
            trimTrailingWhitespace: true,
            insertFinalNewline: false,
            formatOnSave: true,
            organizeImportsOnSave: false,
            fixAllOnSave: true
        )

        #expect(options.textParticipants.trimTrailingWhitespace)
        #expect(options.textParticipants.insertFinalNewline == false)
        #expect(options.formatOnSave)
        #expect(options.organizeImportsOnSave == false)
        #expect(options.fixAllOnSave)
    }

    @Test("performSave 在文件不存在时走 onMissingFile")
    func performSaveReportsMissingFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let controller = EditorSaveController()
        var missing = false
        var succeeded = false
        let writeCalled = FlagBox()

        controller.performSave(
            content: "text",
            url: root.appendingPathComponent("missing.swift"),
            onMissingFile: { missing = true },
            writeFile: { _, _ in writeCalled.value = true },
            onSuccess: { succeeded = true },
            onFailure: { _ in }
        )

        #expect(await waitUntil { missing || succeeded })
        #expect(missing)
        #expect(succeeded == false)
    }

    @Test("performSave 写入成功后触发 onSuccess")
    func performSaveSucceeds() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("a.txt")
        try "old".write(to: fileURL, atomically: true, encoding: .utf8)

        let controller = EditorSaveController()
        var succeeded = false
        var failure: Error?

        controller.performSave(
            content: "new",
            url: fileURL,
            onMissingFile: {},
            writeFile: { content, url in
                try content.write(to: url, atomically: true, encoding: .utf8)
            },
            onSuccess: { succeeded = true },
            onFailure: { failure = $0 }
        )

        #expect(await waitUntil { succeeded || failure != nil })
        #expect(succeeded)
        #expect(failure == nil)
        let written = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(written == "new")
    }

    @Test("performSave 写入抛错时触发 onFailure")
    func performSaveReportsFailure() async throws {
        struct WriteFailure: Error {}

        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        // 文件必须存在，否则会先走 onMissingFile 分支。
        let fileURL = root.appendingPathComponent("a.txt")
        try "old".write(to: fileURL, atomically: true, encoding: .utf8)

        let controller = EditorSaveController()
        var failure: Error?

        controller.performSave(
            content: "new",
            url: fileURL,
            onMissingFile: {},
            writeFile: { _, _ in throw WriteFailure() },
            onSuccess: {},
            onFailure: { failure = $0 }
        )

        #expect(await waitUntil { failure != nil })
        #expect(failure is WriteFailure)
    }

    @Test("scheduleSuccessClear 在延迟后清空状态")
    func schedulesSuccessClear() async {
        let controller = EditorSaveController(successDisplayDuration: 0.05)
        var cleared = false

        controller.scheduleSuccessClear(
            isSavedState: { true },
            clearState: { cleared = true }
        )

        #expect(await waitUntil { cleared })
        #expect(cleared)
    }

    @Test("cancelSuccessClear 取消待执行的清理")
    func cancelsSuccessClear() async {
        let controller = EditorSaveController(successDisplayDuration: 0.2)
        var cleared = false

        controller.scheduleSuccessClear(
            isSavedState: { true },
            clearState: { cleared = true }
        )
        controller.cancelSuccessClear()

        try? await Task.sleep(for: .milliseconds(350))
        #expect(cleared == false)
    }
}

// MARK: - Save state controller

@MainActor
@Suite("EditorSaveStateController")
struct EditorSaveStateControllerExtraTests {

    @Test("保存成功后按顺序推进各副作用")
    func appliesSaveSuccess() {
        let controller = EditorSaveStateController()
        var order: [String] = []
        var states: [EditorSaveState] = []

        controller.applySaveSuccess(
            content: "body",
            markPersistedText: { _ in order.append("mark") },
            clearConflict: { order.append("clearConflict") },
            syncSession: { order.append("sync") },
            scheduleSuccessClear: { order.append("schedule") },
            notifyDidSave: { _ in order.append("notify") },
            setHasUnsavedChanges: { order.append("unsaved:\($0)") },
            setSaveState: { states.append($0) }
        )

        #expect(order.contains("mark"))
        #expect(order.contains("clearConflict"))
        #expect(order.contains("sync"))
        #expect(order.contains("schedule"))
        #expect(order.contains("notify"))
        #expect(order.contains("unsaved:false"))
        #expect(states == [.saved])
    }

    @Test("保存失败时进入 error 状态并同步会话")
    func appliesSaveFailure() {
        let controller = EditorSaveStateController()
        var states: [EditorSaveState] = []
        var synced = false
        var scheduled = false

        controller.applySaveFailure(
            error: NSError(domain: "test", code: 1),
            syncSession: { synced = true },
            scheduleSuccessClear: { scheduled = true },
            setSaveState: { states.append($0) }
        )

        #expect(states.count == 1)
        if case .error = states.first { } else {
            Issue.record("expected .error state, got \(String(describing: states.first))")
        }
        #expect(synced)
        #expect(scheduled)
    }

    @Test("文件缺失时进入 fileNotFound 错误状态")
    func appliesMissingFileFailure() {
        let controller = EditorSaveStateController()
        var states: [EditorSaveState] = []
        var scheduled = false

        controller.applyMissingFileFailure(
            scheduleSuccessClear: { scheduled = true },
            setSaveState: { states.append($0) }
        )

        #expect(states == [.error(EditorStatusMessageCatalog.fileNotFound())])
        #expect(scheduled)
    }

    @Test("保存状态枚举暴露图标")
    func saveStateIcons() {
        #expect(EditorSaveState.idle.icon == "checkmark.circle")
        #expect(EditorSaveState.editing.icon == "pencil.circle")
        #expect(EditorSaveState.saving.icon == "arrow.triangle.2.circlepath")
        #expect(EditorSaveState.saved.icon == "checkmark.circle.fill")
        #expect(EditorSaveState.conflict("x").icon.contains("exclamationmark"))
        #expect(EditorSaveState.error("x").icon.contains("exclamationmark"))
    }
}

// MARK: - Policy

@Suite("EditorSaveWorkflowPolicy")
struct EditorSaveWorkflowPolicyExtraTests {

    @Test("策略只按未保存标记与保存中状态判断")
    func policyDecisions() {
        #expect(EditorSaveWorkflowPolicy.shouldSaveNowIfNeeded(hasUnsavedChanges: true))
        #expect(EditorSaveWorkflowPolicy.shouldSaveNowIfNeeded(hasUnsavedChanges: false) == false)
        #expect(EditorSaveWorkflowPolicy.shouldRunSaveTask(isSaving: false))
        #expect(EditorSaveWorkflowPolicy.shouldRunSaveTask(isSaving: true) == false)
    }
}
