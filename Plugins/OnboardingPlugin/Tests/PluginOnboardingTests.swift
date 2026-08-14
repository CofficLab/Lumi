import Foundation
import KernelLumi
import Testing
@testable import OnboardingPlugin

@Test @MainActor func packageLoads() throws {
    #expect(OnboardingPlugin().id == "com.coffic.lumi.plugin.onboarding")
    #expect(OnboardingPlugin().policy == .alwaysOn)
    #expect(OnboardingPlugin().policy.shouldRegister)
}

@Test @MainActor func onboardingPluginProvidesPages() throws {
    let pages = OnboardingPlugin().onboardingPages(kernel: KernelLumi())

    #expect(pages.count == 2)
}

@Test @MainActor func onboardingPageMakesContent() throws {
    let pages = OnboardingPlugin().onboardingPages(kernel: KernelLumi())

    for page in pages {
        let content = page
        #expect("\(content)" != "")
    }
}

@Test func onboardingSecondAndThirdPagesUsePluginChineseLocalizations() {
    let simplifiedChinese = Locale(identifier: "zh-Hans")

    #expect(OnboardingPageLocalization.string("Configure AI", locale: simplifiedChinese) == "配置 AI")
    #expect(OnboardingPageLocalization.string("A quick tour", locale: simplifiedChinese) == "快速导览")
    #expect(OnboardingPageLocalization.string("Desktop tools", locale: simplifiedChinese) == "桌面工具")
}

@Test func onboardingStoreReportsSaveResultAndReloadsCompletion() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = PluginStore(settingsDirectory: directory)

    #expect(store.setCompleted(true) == true)

    let reloadedStore = PluginStore(settingsDirectory: directory)
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

    let store = PluginStore(settingsDirectory: directory)

    #expect(store.completed == false)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.setCompleted(true) == true)

    let reloadedStore = PluginStore(settingsDirectory: directory)
    #expect(reloadedStore.completed == true)
}

@Test func onboardingStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = PluginStore(settingsDirectory: blockedDirectory)

    #expect(store.setCompleted(true) == false)
    #expect(store.completed == false)
}

@Test func onboardingPageIndexingClampsInvalidSteps() {
    #expect(PageIndexing.clampedIndex(-2, pageCount: 5) == 0)
    #expect(PageIndexing.clampedIndex(2, pageCount: 5) == 2)
    #expect(PageIndexing.clampedIndex(7, pageCount: 5) == 4)
    #expect(PageIndexing.clampedIndex(7, pageCount: 0) == 0)
}

@Test @MainActor func onboardingViewModelKeepsOnboardingVisibleWhenCompletionCannotBeSaved() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingViewModel-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let viewModel = PluginViewModel(store: PluginStore(settingsDirectory: blockedDirectory))
    viewModel.start()
    viewModel.complete()

    #expect(viewModel.isPresentingOnboarding == true)
    #expect(viewModel.persistenceErrorMessage?.isEmpty == false)
}

@Test @MainActor func onboardingViewModelIgnoresRepeatedNextStepDuringTransition() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OnboardingViewModel-RepeatedNext-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let viewModel = PluginViewModel(store: PluginStore(settingsDirectory: directory))
    viewModel.start()

    viewModel.nextStep(totalSteps: 2)
    viewModel.nextStep(totalSteps: 2)
    try await Task.sleep(nanoseconds: 250_000_000)

    #expect(viewModel.currentStep == 1)
    #expect(viewModel.isPresentingOnboarding == true)
}
