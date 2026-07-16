import Foundation
import LumiCoreKit
import Testing
@testable import OnboardingPlugin

@Test func packageLoads() async throws {
    #expect(OnboardingPlugin.info.id == "com.coffic.lumi.plugin.onboarding")
    #expect(OnboardingPlugin.policy == .alwaysOn)
    #expect(OnboardingPlugin.policy.shouldRegister)
}

@MainActor
@Test func onboardingPluginProvidesPages() throws {
    let context = LumiPluginContext(
        activeSectionID: "test",
        activeSectionTitle: "Test"
    )
    let pages = OnboardingPlugin.onboardingPages(context: context)

    #expect(pages.count == 2)
}

@MainActor
@Test func onboardingPageMakesContent() throws {
    let context = LumiPluginContext(
        activeSectionID: "test",
        activeSectionTitle: "Test"
    )
    let pages = OnboardingPlugin.onboardingPages(context: context)

    for page in pages {
        let content = page
        #expect("\(content)" != "")
    }
}

@MainActor
@Test func defaultOnboardingPagesReturnsEmpty() throws {
    struct DummyPlugin: LumiPlugin {
        static let info = LumiPluginInfo(
            id: "test.dummy",
            displayName: "Dummy",
            description: "A test plugin",
            order: 0,
            policy: .alwaysOn,
            category: .general,
            iconName: "star"
        )
    }

    let context = LumiPluginContext(
        activeSectionID: "test",
        activeSectionTitle: "Test"
    )
    let pages = DummyPlugin.onboardingPages(context: context)
    #expect(pages.isEmpty)
}

@Test func onboardingStoreReportsSaveResultAndReloadsCompletion() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = OnboardingPluginStore(settingsDirectory: directory)

    #expect(store.setCompleted(true) == true)

    let reloadedStore = OnboardingPluginStore(settingsDirectory: directory)
    #expect(reloadedStore.completed == true)
}

@Test func onboardingStoreQuarantinesInvalidStateFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let stateURL = directory.appendingPathComponent("onboarding_state.plist")
    let corruptURL = directory.appendingPathComponent("onboarding_state.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: stateURL)

    let store = OnboardingPluginStore(settingsDirectory: directory)

    #expect(store.completed == false)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.setCompleted(true) == true)

    let reloadedStore = OnboardingPluginStore(settingsDirectory: directory)
    #expect(reloadedStore.completed == true)
}

@Test func onboardingStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = OnboardingPluginStore(settingsDirectory: blockedDirectory)

    #expect(store.setCompleted(true) == false)
    #expect(store.completed == false)
}

@Test func onboardingPageIndexingClampsInvalidSteps() {
    #expect(OnboardingPageIndexing.clampedIndex(-2, pageCount: 5) == 0)
    #expect(OnboardingPageIndexing.clampedIndex(2, pageCount: 5) == 2)
    #expect(OnboardingPageIndexing.clampedIndex(7, pageCount: 5) == 4)
    #expect(OnboardingPageIndexing.clampedIndex(7, pageCount: 0) == 0)
}

@MainActor
@Test func onboardingViewModelKeepsOnboardingVisibleWhenCompletionCannotBeSaved() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingViewModel-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let viewModel = OnboardingPluginViewModel(store: OnboardingPluginStore(settingsDirectory: blockedDirectory))
    viewModel.start()
    viewModel.complete()

    #expect(viewModel.isPresentingOnboarding == true)
    #expect(viewModel.persistenceErrorMessage?.isEmpty == false)
}

@MainActor
@Test func onboardingViewModelIgnoresRepeatedNextStepDuringTransition() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingViewModel-RepeatedNext-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let viewModel = OnboardingPluginViewModel(store: OnboardingPluginStore(settingsDirectory: directory))
    viewModel.start()

    viewModel.nextStep(totalSteps: 2)
    viewModel.nextStep(totalSteps: 2)
    try await Task.sleep(nanoseconds: 250_000_000)

    #expect(viewModel.currentStep == 1)
    #expect(viewModel.isPresentingOnboarding == true)
}
