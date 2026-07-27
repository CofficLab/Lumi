import Foundation
import Testing
import SwiftUI
@testable import LumiKernel

@Suite("LumiKernel Tests")
@MainActor
struct LumiKernelTests {

    @Test("Service registration and resolution")
    func testServiceRegistration() async throws {
        let kernel = LumiKernel()

        // 测试服务注册
        let storage = MockStorageService()
        kernel.registerService(StorageProviding.self, storage)

        // 测试服务解析
        let resolved = kernel.resolveService(StorageProviding.self)
        #expect(resolved != nil)
    }

    @Test("Conversation input service can be registered and resolved")
    func testConversationInputServiceRegistration() async throws {
        let kernel = LumiKernel()
        let input = MockConversationInputService()

        kernel.registerConversationInputService(input)

        let resolved = kernel.conversationInput
        #expect(resolved != nil)
        #expect(resolved as? MockConversationInputService === input)
    }

    @Test("Conversation input state is shared through kernel")
    func testConversationInputStateSharedThroughKernel() async throws {
        let kernel = LumiKernel()
        let input = MockConversationInputService()
        kernel.registerConversationInputService(input)

        kernel.conversationInput?.text = "hello kernel"
        kernel.conversationInput?.inputHeight = 120
        kernel.conversationInput?.isInputFocused = true
        kernel.conversationInput?.inputCursorPosition = 3
        kernel.conversationInput?.errorMessage = "boom"

        #expect(input.text == "hello kernel")
        #expect(input.inputHeight == 120)
        #expect(input.isInputFocused == true)
        #expect(input.inputCursorPosition == 3)
        #expect(input.errorMessage == "boom")
    }

    @Test("Conversation input can accept conversation file references")
    func testConversationInputConversationReferences() async throws {
        let kernel = LumiKernel()
        let input = MockConversationInputService()
        kernel.registerConversationInputService(input)

        let fileA = URL(fileURLWithPath: "/tmp/A.swift")
        let fileB = URL(fileURLWithPath: "/tmp/B.swift")

        kernel.conversationInput?.addToConversation(fileURLs: [fileA, fileB], windowId: nil)

        #expect(input.text == """
        Files to add to conversation:
        - /tmp/A.swift
        - /tmp/B.swift
        """)
        #expect(input.isInputFocused == true)
    }

    @Test("Project service can store and expose current file")
    func testProjectServiceCurrentFile() async throws {
        let kernel = LumiKernel()
        let project = MockProjectService()
        kernel.registerProject(project)

        let fileURL = URL(fileURLWithPath: "/tmp/Project/Sources/Main.swift")
        kernel.project?.updateCurrentFile(fileURL)

        #expect(project.openFileURLs == [fileURL.standardizedFileURL])
        #expect(project.currentFileURL == fileURL.standardizedFileURL)
        #expect(kernel.project?.currentFileURL == fileURL.standardizedFileURL)
        #expect(kernel.project?.openFileURLs == [fileURL.standardizedFileURL])
    }
}

// MARK: - Mock Services

/// Mock 存储服务实现
@MainActor
private final class MockStorageService: StorageProviding {
    var dataRootDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}

@MainActor
private final class MockProjectService: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL] = []
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo] = []

    func openProject(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        currentProject = ProjectInfo(name: url.lastPathComponent, path: path)
        currentFileURL = nil
    }

    func updateCurrentFile(_ fileURL: URL?) {
        let standardizedURL = fileURL?.standardizedFileURL
        currentFileURL = standardizedURL
        guard let standardizedURL else { return }
        updateOpenFiles(openFileURLs + [standardizedURL])
    }

    func updateOpenFiles(_ fileURLs: [URL]) {
        var uniqueURLs: [URL] = []
        for fileURL in fileURLs {
            let standardizedURL = fileURL.standardizedFileURL
            if !uniqueURLs.contains(standardizedURL) {
                uniqueURLs.append(standardizedURL)
            }
        }
        openFileURLs = uniqueURLs
    }

    func closeProject() async {
        currentProject = nil
        openFileURLs = []
        currentFileURL = nil
    }

    func refreshProjects() async throws {}
}

@MainActor
private final class MockConversationInputService: ConversationInputProviding {
    @Published var text: String = ""
    @Published var inputHeight: CGFloat = 64
    @Published var isInputFocused: Bool = false
    @Published var inputCursorPosition: Int = 0
    @Published var errorMessage: String?

    var isSendingValue: Bool = false
    var canSendValue: Bool = true
    var stopCallCount: Int = 0
    var sendCallCount: Int = 0

    func isSending(kernel: LumiKernel) -> Bool {
        isSendingValue
    }

    func canSend(kernel: LumiKernel) -> Bool {
        canSendValue
    }

    func send(kernel: LumiKernel) {
        sendCallCount += 1
    }

    func stop(kernel: LumiKernel) {
        stopCallCount += 1
    }

    func addToConversation(fileURLs: [URL], windowId: UUID?) {
        let paths = fileURLs.map { $0.standardizedFileURL.path }
        guard !paths.isEmpty else { return }

        let referenceBlock = (["Files to add to conversation:"] + paths.map { "- \($0)" })
            .joined(separator: "\n")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = referenceBlock
        } else {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + referenceBlock
        }
        isInputFocused = true
    }
}
