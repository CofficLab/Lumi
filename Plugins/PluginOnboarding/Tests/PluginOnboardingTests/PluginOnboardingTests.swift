import Foundation
import Testing
@testable import PluginOnboarding

@Test func packageLoads() async throws {
    #expect(OnboardingPlugin.id == "Onboarding")
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
